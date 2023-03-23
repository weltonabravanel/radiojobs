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

using Gst;

namespace Gradio{
	public class AudioPlayer : GLib.Object {

		public uint current_bitrate_tag { get; set;}
		public string current_title_tag { get; set;}
		public RadioStation station { get; set;}
		public string status_message { get; set;}

		private const int reconnect_delay = 10000;
		private uint delayed_changed_id;

		public double volume {
			get{return playbin.volume;}
			set{playbin.volume = value;}
		}

		public Gst.State state{
			get{return playbin.current_state; }
			set{playbin.set_state(value);}
		}

		private dynamic Element playbin;
		private CodecInstaller codec;

		public AudioPlayer(){
			Gst.PbUtils.init();

			playbin = ElementFactory.make ("playbin", "playbin");
			codec = new CodecInstaller();
			volume = App.settings.volume_position;

			if(App.settings.previous_station != 0 && App.settings.resume_playback_on_startup){
				Util.get_station_by_id.begin(App.settings.previous_station, (obj, res) => {
					station = Util.get_station_by_id.end(res);
				});
			}

			notify["state"].connect(() => {
				switch(state){
					case Gst.State.PLAYING: status_message = "Connected to radio station."; break;
					default: current_bitrate_tag = 0; current_title_tag = ""; status_message = "Not connected.";break;
				}
			});

			notify["station"].connect(new_station);
		}

		private async void new_station(){
			// reset tag data
			current_bitrate_tag = 0;
			current_title_tag = "";

			state = Gst.State.NULL;

			App.settings.previous_station = int.parse(station.id);
			string address = yield station.get_stream_address();

			if(station.is_broken){
				status_message = "This station is broken.";
				address = "";
				playbin.uri = address;
				return;
			}

			message("Connecting to: %s", address);

			playbin.uri = address;
			Gst.Bus bus = playbin.get_bus ();
			bus.add_watch (1, bus_callback);

			state = Gst.State.PLAYING;
		}

		private bool bus_callback (Gst.Bus bus, Gst.Message m) {
			switch (m.type) {
				case Gst.MessageType.ELEMENT:
					// TODO: Improve the handling of missing codecs.
				    	if(Gst.PbUtils.is_missing_plugin_message(m)) {
				    		state = Gst.State.NULL;
				    		status_message = "A required codec is missing.";
				    		codec.install_missing_codec(m);
				    	}

            				break;
				case MessageType.ERROR:
					GLib.Error err; string debug;
					m.parse_error (out err, out debug);

					message(err.message);
					message(debug);

					state = Gst.State.NULL;
					status_message = err.message;
					reset_reconnect_timeout();
					break;
				case MessageType.EOS:
					state = Gst.State.NULL;
					status_message = "End of stream";
					reset_reconnect_timeout();
					break;
				case MessageType.STATE_CHANGED: notify_property("state"); break;
				case MessageType.TAG:
					Gst.TagList tag_list = null;
					m.parse_tag(out tag_list);

					string current_title;
					uint current_bitrate;

					string test;

					tag_list.get_string("title", out current_title);
					current_title_tag = current_title;

					tag_list.get_uint("bitrate", out current_bitrate);
					current_bitrate_tag = current_bitrate/1000;

					tag_list.get_string("genre", out test);

					break;
				default:
					break;
			}
			return true;
		}

		public void toggle_play_stop(){
			if(playbin.current_state == Gst.State.NULL)
				state = State.PLAYING;
			else
				state = State.NULL;
		}

		private void reset_reconnect_timeout(){
			if(delayed_changed_id > 0)
				Source.remove(delayed_changed_id);
			delayed_changed_id = Timeout.add(reconnect_delay, reconnect);
		}

		private bool reconnect(){
			new_station.begin();

			delayed_changed_id = 0;
			return false;
		}

	}
}
