/* This file is part of Gradio.
 *
 * Gradio is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Gradio is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Gradio.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
using Gst;

namespace Gradio{

	public enum WindowMode {
		LIBRARY,
		COLLECTION_ITEMS,
		SEARCH,
		SETTINGS
	}

	[GtkTemplate (ui = "/de/haecker-felix/gradio/ui/main-window.ui")]
	public class MainWindow : Gtk.ApplicationWindow {

		public string[] page_name = { "library", "collections", "collection_items", "search", "settings"};

		public Gradio.Headerbar header;
		PlayerToolbar player_toolbar;

		[GtkChild] private Stack MainStack;
		[GtkChild] private Box Bottom;

		// Different pages
		CollectionItemsPage collection_items_page;
		public SearchPage search_page;
		LibraryPage library_page;
		SettingsPage settings_page;

		// History of the pages
		GLib.Queue<WindowMode> mode_queue = new GLib.Queue<WindowMode>();
		WindowMode current_mode;
		private bool in_mode_change = false;

		// Selection
		[GtkChild] private Revealer SelectionToolbarRevealer;
		[GtkChild] private Box SelectionToolbarBox;
		private SelectionToolbar selection_toolbar;
		private ulong selection_changed_id = 0;
		public StationModel current_selection { get; set;}

		// In-App Notification
		[GtkChild] private Button NotificationCloseButton;
		[GtkChild] private Label NotificationLabel;
		[GtkChild] private Revealer NotificationRevealer;

		// Details sidebar
		[GtkChild] private Box DetailsBox;
		public DetailsBox details_box;

		// Tray icon
		public signal void tray_activate();
		private Gtk.StatusIcon trayicon;

		private App app;

		public MainWindow (App appl) {
	       		GLib.Object(application: appl, show_menubar: false);
			app = appl;

			setup_view();
			setup_tray_icon();
			connect_signals();

			this.show_all();
		}

		private void setup_view(){
			header = new Gradio.Headerbar();
			this.set_titlebar(header);

			selection_toolbar = new SelectionToolbar(this);
			SelectionToolbarBox.add(selection_toolbar);

			library_page = new LibraryPage();
			MainStack.add_named(library_page, page_name[WindowMode.LIBRARY]);

			collection_items_page = new CollectionItemsPage();
			MainStack.add_named(collection_items_page, page_name[WindowMode.COLLECTION_ITEMS]);

			settings_page = new SettingsPage();
			MainStack.add_named(settings_page, page_name[WindowMode.SETTINGS]);

			details_box = new Gradio.DetailsBox();
			DetailsBox.add(details_box);

			// showing library on startup
			set_mode(WindowMode.LIBRARY);

			var gtk_settings = Gtk.Settings.get_default ();
			gtk_settings.gtk_application_prefer_dark_theme = App.settings.enable_dark_theme;

			// menubar isn't required, because the appmenu is now integrated into Gradio.MenuButton
			this.set_show_menubar(false);

	        	player_toolbar = new PlayerToolbar();
	       		player_toolbar.set_visible(false);
	       		Bottom.pack_end(player_toolbar);

	       		// Load css
			Util.add_stylesheet();

			// restore window size
	       		this.set_default_size(App.settings.window_width, App.settings.window_height);
		}

		private void connect_signals(){
			this.size_allocate.connect((a) => {
				int width, height;
				this.get_size (out width, out height);

			 	App.settings.window_width = width;
			 	App.settings.window_height = height;
			});

			header.SearchToggleButton.clicked.connect(() => {
				if(!header.SearchToggleButton.active){
					if(current_mode == WindowMode.SEARCH) set_mode(mode_queue.pop_head(), true);
				}else{
					set_mode(WindowMode.SEARCH);
				}
			});
			header.BackButton.clicked.connect(() => {set_mode(mode_queue.pop_head(), true);});
			header.selection_canceled.connect(() => {set_selection_mode(false);});
			header.selection_started.connect(() => {set_selection_mode(true);});
			NotificationCloseButton.clicked.connect(hide_notification);
		}

		private void setup_tray_icon(){
			trayicon = new Gtk.StatusIcon.from_icon_name("de.haeckerfelix.gradio-symbolic");
      			trayicon.set_tooltip_text ("Click to restore...");
      			trayicon.activate.connect(() => tray_activate());

      			show_tray_icon(App.settings.enable_tray_icon);
		}

		public void show_tray_icon(bool b){
			trayicon.set_visible(b);
		}

		public void set_selection_mode(bool b){
			if(App.player.station != null) player_toolbar.set_visible(!b);
			Page page = (Page)MainStack.get_visible_child();
			page.set_selection_mode(b);
			SelectionToolbarRevealer.set_reveal_child(b);
			header.show_selection_bar(b);
		}

		public void select_all(){
			Page page = (Page)MainStack.get_visible_child();
			page.select_all();
		}

		public void select_none(){
			Page page = (Page)MainStack.get_visible_child();
			page.select_none();
		}

		private void selection_changed(){
			Page page = (Page)MainStack.get_visible_child();
			current_selection = page.get_selection();
			header.set_selected_items((int)current_selection.get_n_items());
		}

		private void title_changed(){
			header.set_title("");
			header.set_subtitle("");
			header.set_title(((Page)MainStack.get_visible_child()).get_title());
			header.set_subtitle(((Page)MainStack.get_visible_child()).get_subtitle());
		}

		public void show_notification(string text){
			NotificationLabel.set_text(text);
			NotificationRevealer.set_reveal_child(true);
		}

		public void hide_notification(){
			NotificationRevealer.set_reveal_child(false);
		}

		public void set_mode(WindowMode mode, bool dont_write_history = false){
			if(in_mode_change == true)
				return;

			// insert actual mode in the "back" history
			if(!dont_write_history) mode_queue.push_head(current_mode);
			in_mode_change = true;

			// set new mode
			current_mode = mode;

			// Disconnect old signals and deactivate selection mode
			Page page = (Page)MainStack.get_visible_child();
			page.set_selection_mode(false);
			page.selection_changed.disconnect(selection_changed);
			page.title_changed.disconnect(title_changed);
			if (selection_changed_id != 0) page.disconnect(selection_changed_id);

			// set headerbar to default
			header.show_default_buttons();
			header.SearchToggleButton.set_active(mode == WindowMode.SEARCH);

			// disable selection mode
			set_selection_mode(false);

			// "delete" search page if necessary
			if(current_mode != WindowMode.SEARCH && search_page != null){
				MainStack.remove(search_page);
				search_page = null;
			}

			// do action for mode
			switch(current_mode){
				case WindowMode.LIBRARY: {
					mode_queue.clear();
					break;
				};
				case WindowMode.SEARCH: {
					if(search_page == null){
						search_page = new SearchPage();
						MainStack.add_named(search_page, page_name[WindowMode.SEARCH]);
					}
					header.MenuBox.set_visible(false);
					break;
				};
				case WindowMode.COLLECTION_ITEMS: {
					Collection collection = library_page.selected_collection;
					collection_items_page.set_collection(collection);
					break;
				};
				case WindowMode.SETTINGS: {
					header.MenuBox.set_visible(false);
					header.SearchToggleButton.set_visible(false);
					header.SelectButton.set_visible(false);
					break;
				}
			}

			// show back button if needed
			header.BackButton.set_visible(!(mode_queue.is_empty()));

			// switch page
			MainStack.set_visible_child_name(page_name[current_mode]);

			// connect new signals
			Page new_page = (Page)MainStack.get_visible_child();
			new_page.selection_changed.connect(selection_changed);
			new_page.title_changed.connect(title_changed);
			selection_changed_id = new_page.selection_mode_enabled.connect(() => {set_selection_mode(true);});;

			// update title and subtitle
			title_changed();

			in_mode_change = false;
			message("Changed page mode to \"%s\"", page_name[current_mode]);
		}

		[GtkCallback]
		public bool on_key_pressed (Gdk.EventKey event) {
			var default_modifiers = Gtk.accelerator_get_default_mod_mask ();

			// Quit
			if ((event.keyval == Gdk.Key.q || event.keyval == Gdk.Key.Q) && (event.state & default_modifiers) == Gdk.ModifierType.CONTROL_MASK) {
				app.quit();
				return true;
			}

			// Play / Pause
			if ((event.keyval == Gdk.Key.space) && (event.state & default_modifiers) == Gdk.ModifierType.CONTROL_MASK) {
				App.player.toggle_play_stop();
				return true;
			}

			// details sidebar for actual station
			if ((event.keyval == Gdk.Key.i) && (event.state & default_modifiers) == Gdk.ModifierType.CONTROL_MASK) {
				if(App.player.station != null){
					details_box.set_station(App.player.station);
					details_box.set_visible(true);
				}
				return true;
			}

			// show search
			if ((event.keyval == Gdk.Key.f) && (event.state & default_modifiers) == Gdk.ModifierType.CONTROL_MASK) {
				set_mode(WindowMode.SEARCH);
				return true;
			}

			// show library
			if ((event.keyval == Gdk.Key.l) && (event.state & default_modifiers) == Gdk.ModifierType.CONTROL_MASK) {
				set_mode(WindowMode.LIBRARY);
				return true;
			}

			return false;
		}

	}
}
