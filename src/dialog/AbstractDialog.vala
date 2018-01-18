/* Copyright 2014 Nicolas Laplante
*
* This file is part of envelope.
*
* envelope is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* envelope is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with envelope. If not, see http://www.gnu.org/licenses/.
*/

namespace Envelope.Dialog {
    public abstract class AbstractOkCancelDialog : Gtk.Dialog {
        protected Gtk.Button ok_button { get; private set; }
        protected Gtk.Button cancel_button { get; private set; }

        protected AbstractOkCancelDialog () {
            build_ui ();
            connect_signals ();
        }

        private void build_ui () {
            border_width = 20;

            Gtk.Box content = get_content_area () as Gtk.Box;
            content.spacing = 20;

            content.add (build_content ());

            cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CLOSE) as Gtk.Button;
            ok_button = add_button (_("Ok"), Gtk.ResponseType.APPLY) as Gtk.Button;
            ok_button.get_style_context ().add_class("suggested-action");;
        }

        // connect signals on Cancel and OK buttons. Don't forget to call base.connect_signals () if you
        // override this method.
        protected virtual void connect_signals () {
            response.connect ((source, response_id) => {
                switch (response_id) {
                    case Gtk.ResponseType.APPLY:
                        apply_cb ();
                        destroy ();

                    break;

                    case Gtk.ResponseType.CLOSE:
                        cancel_cb ();
                        destroy ();

                    break;
                }
            });
        }

        /**
         * Override this method to build dialog content. Return the topmost container.
         */
        protected abstract Gtk.Widget build_content ();

        /**
         * Override this method to execute actions when the OK button is activated
         */
        protected abstract void apply_cb ();

        /**
         * Override this method to execute actions when the Cancel button is activated.
         */
        protected abstract void cancel_cb ();
    }
}
