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

	[GtkTemplate (ui = "/de/haecker-felix/gradio/ui/page/search-page.ui")]
	public class SearchPage : Gtk.Box, Page{
		[GtkChild] private Box ResultsBox;
		[GtkChild] private Label ResultsLabel;
		[GtkChild] private Box SearchBox;
		[GtkChild] private Stack SearchStack;
		[GtkChild] private Stack SectionStack;
		private SearchBar searchbar;

		private StationModel search_station_model;
		private StationProvider search_station_provider;

		[GtkChild] private Frame MostVotesFrame;
		[GtkChild] private Frame RecentlyClickedFrame;
		[GtkChild] private Frame MostClicksFrame;

		private MainBox search_mainbox;
		private MainBox most_votes_mainbox;
		private MainBox recently_clicked_mainbox;
		private MainBox most_clicks_mainbox;

		public SearchPage(){
			search_station_model =  new StationModel();
			search_station_provider = new StationProvider(ref search_station_model);

			search_station_provider.ready.connect(() => {
				if(search_station_model.get_n_items() == 0){
					SearchStack.set_visible_child_name("no-results");
				}else{
					SearchStack.set_visible_child_name("results");
				}
				ResultsLabel.set_text(search_station_model.get_n_items().to_string());
			});

			searchbar = new Gradio.SearchBar(ref search_station_provider);
			searchbar.timeout_reset.connect(() => {SearchStack.set_visible_child_name("loading");});
			searchbar.show_search_results.connect(show_search);
			searchbar.BackButton.clicked.connect(show_discover);
			SearchBox.add(searchbar);

			setup_discover_section();
			setup_search_section();
		}

		private void setup_discover_section(){
			HashTable<string, string> filter_table = new HashTable<string, string> (str_hash, str_equal);

			most_votes_mainbox = new MainBox();
			recently_clicked_mainbox = new MainBox();
			most_clicks_mainbox = new MainBox();

			StationModel most_votes_model = new StationModel();
			StationModel recently_clicked_model = new StationModel();
			StationModel most_clicks_model = new StationModel();

			StationProvider most_votes_provider = new StationProvider(ref most_votes_model);
			StationProvider recently_clicked_provider = new StationProvider(ref recently_clicked_model);
			StationProvider most_clicks_provider = new StationProvider(ref most_clicks_model);

			most_votes_provider.get_stations.begin(RadioBrowser.most_votes(14), filter_table);
			recently_clicked_provider.get_stations.begin(RadioBrowser.recently_clicked(14), filter_table);
			most_clicks_provider.get_stations.begin(RadioBrowser.most_clicks(14), filter_table);

			most_votes_mainbox.set_model(most_votes_model);
			recently_clicked_mainbox.set_model(recently_clicked_model);
			most_clicks_mainbox.set_model(most_clicks_model);

			most_votes_mainbox.set_show_secondary_text(false);
			recently_clicked_mainbox.set_show_secondary_text(false);
			most_clicks_mainbox.set_show_secondary_text(false);

			MostVotesFrame.add(most_votes_mainbox);
			RecentlyClickedFrame.add(recently_clicked_mainbox);
			MostClicksFrame.add(most_clicks_mainbox);

			most_votes_mainbox.selection_changed.connect(() => {selection_changed();});
			recently_clicked_mainbox.selection_changed.connect(() => {selection_changed();});
			most_clicks_mainbox.selection_changed.connect(() => {selection_changed();});

			most_votes_mainbox.selection_mode_request.connect(() => {selection_mode_enabled();});
			recently_clicked_mainbox.selection_mode_request.connect(() => {selection_mode_enabled();});
			most_clicks_mainbox.selection_mode_request.connect(() => {selection_mode_enabled();});
		}

		private void setup_search_section(){
			search_mainbox = new MainBox();
			search_mainbox.set_model(search_station_model);
			search_mainbox.selection_changed.connect(() => {selection_changed();});
			search_mainbox.selection_mode_request.connect(() => {selection_mode_enabled();});
			ResultsBox.add(search_mainbox);
		}

		private void show_search(){
			SectionStack.set_visible_child_name("search");
			searchbar.BackButton.set_visible(true);
		}

		private void show_discover(){
			SectionStack.set_visible_child_name("discover");
			searchbar.BackButton.set_visible(false);
		}

		public void set_search(string term){
			searchbar.set_search(term);
		}

		public void set_selection_mode(bool b){
			search_mainbox.set_selection_mode(b);
			most_clicks_mainbox.set_selection_mode(b);
			recently_clicked_mainbox.set_selection_mode(b);
			most_votes_mainbox.set_selection_mode(b);
			SearchBox.set_visible(!b);
		}

		public void select_all(){
			if(SectionStack.get_visible_child_name() == "discover"){
				most_clicks_mainbox.select_all();
				recently_clicked_mainbox.select_all();
				most_votes_mainbox.select_all();
			}

			if(SectionStack.get_visible_child_name() == "search"){
				search_mainbox.select_all();
			}
		}

		public void select_none(){
			search_mainbox.unselect_all();
			most_clicks_mainbox.unselect_all();
			recently_clicked_mainbox.unselect_all();
			most_votes_mainbox.unselect_all();
		}

		public StationModel get_selection(){
			StationModel model = new StationModel();

			List<Gd.MainBoxItem> selection = search_mainbox.get_selection();
			List<Gd.MainBoxItem> most_clicks_selection = most_clicks_mainbox.get_selection();
			List<Gd.MainBoxItem> recently_clicked_selection = recently_clicked_mainbox.get_selection();
			List<Gd.MainBoxItem> most_votes_selection = most_votes_mainbox.get_selection();

			foreach(Gd.MainBoxItem item in most_clicks_selection) model.add_item(item);
			foreach(Gd.MainBoxItem item in recently_clicked_selection) model.add_item(item);
			foreach(Gd.MainBoxItem item in most_votes_selection) model.add_item(item);
			foreach(Gd.MainBoxItem item in selection) model.add_item(item);

			return model;
		}

		public string get_title(){
			return _("Search");
		}

		[GtkCallback]
		private void MostVotesButton_clicked(){
			searchbar.reset_filters();
			searchbar.set_sort("votes", "descending");
			show_search();
		}

		[GtkCallback]
		private void RecentlyClickedButton_clicked(){
			searchbar.reset_filters();
			searchbar.set_sort("clicktimestamp", "descending");
			show_search();
		}

		[GtkCallback]
		private void MostClicksButton_clicked(){
			searchbar.reset_filters();
			searchbar.set_sort("clicks", "descending");
			show_search();
		}
	}
}


