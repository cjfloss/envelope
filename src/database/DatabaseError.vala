/* Copyright (C) 2009,2011 Jens Georg <mail@jensge.org>.
*
* Author: Jens Georg <mail@jensge.org> for Rygel
*
* Adapted to envelope
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

namespace Envelope.Database {
    public errordomain DatabaseError {
        SQLITE_ERROR, /// Error code translated from SQLite
        OPEN,         /// Error while opening database file
        PREPARE,      /// Error while preparing a statement
        BIND,         /// Error while binding values to a statement
        STEP,         /// Error while running through a result set
        CONSTRAINT    /// Sqlite Constraint Error
    }
}