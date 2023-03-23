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

	[GtkTemplate (ui = "/de/haecker-felix/gradio/ui/item/button-item.ui")]
	public class ButtonItem : Gtk.ListBoxRow, GroupBoxItem{

		[GtkChild] private Label Title;
		[GtkChild] private Label Subtitle;

		public signal void btn_clicked ();

		public ButtonItem(string title, string subtitle = ""){
			Title.set_text(title);
			Subtitle.set_text(subtitle);
		}

		private void clicked(){
			btn_clicked();
		}
	}
}

