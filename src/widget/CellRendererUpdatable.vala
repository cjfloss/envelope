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

namespace Envelope.Widget {

    /**
     * The CellRendererUpdatable class is meant to be used inside a CellRendererPopoverContainer.
     * It allows to use multiple UIs inside a single CellRendererPopoverContainer. This can
     * be useful when the UI to show in a popover has to change depending on the row it
     * currently points to.
     *
     * In Envelope, it is used to show a popover on categories in the sidebar.
     */
    public abstract class CellRendererUpdatable : Gtk.Grid {

        /**
         * Updates the UI of this instance
         */
        public abstract void update ();

        /**
         * Signal which is emitted when this instance is dismissed
         */
        public signal void dismiss ();
    }

}
