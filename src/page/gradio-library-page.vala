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

namespace Gradio{

	[GtkTemplate (ui = "/de/haecker-felix/gradio/ui/page/library-page.ui")]
	public class LibraryPage : Gtk.Box, Page{

		[GtkChild] Viewport ScrollViewport;
		[GtkChild] Stack LibraryStack;

		private MainBox mainbox;

		public Collection selected_collection;

		public LibraryPage(){
			mainbox = new MainBox();
			mainbox.set_model(Library.station_model);
			mainbox.selection_changed.connect(() => {selection_changed();});
			mainbox.selection_mode_request.connect(() => {selection_mode_enabled();});
			ScrollViewport.add(mainbox);

			mainbox.collection_clicked.connect((collection) => {
				selected_collection = collection;
				App.window.set_mode(WindowMode.COLLECTION_ITEMS);
			});

			Library.station_model.items_changed.connect(() => {title_changed();});
			Library.station_model.items_changed.connect(update_page);
			App.library.notify["busy"].connect(() => {title_changed();});
			title_changed();
			update_page();
		}

		private void update_page(){
			if(Library.station_model.get_n_items() == 0)
				LibraryStack.set_visible_child_name("empty");
			else
				LibraryStack.set_visible_child_name("items");
		}

		public void set_selection_mode(bool b){
			mainbox.set_selection_mode(b);
		}

		public void select_all(){
			mainbox.select_all();
		}

		public void select_none(){
			mainbox.unselect_all();
		}

		public StationModel get_selection(){
			List<Gd.MainBoxItem> selection = mainbox.get_selection();
			StationModel model = new StationModel();

			foreach(Gd.MainBoxItem item in selection){
				model.add_item(item);
			}
			return model;
		}

		public string get_title(){
			return _("Library");
		}

		public string get_subtitle(){
			if(App.library.busy)
				return _("Fetching station data…");
			else
				return _("Items: ") + Library.station_model.get_n_items().to_string();
		}

		[GtkCallback]
		private void SearchButton_clicked(Gtk.Button button){
			App.window.set_mode(WindowMode.SEARCH);
		}
	}
}
