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

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "config.h")]
namespace Build {
  public const string PROGRAM_NAME;
  public const string DATADIR;
  public const string PKGDATADIR;
  public const string GETTEXT_PACKAGE;
  public const string RELEASE_NAME;
  public const string VERSION;
  public const string VERSION_INFO;
  public const string GIT_BRANCH;
  public const string GIT_COMMIT_HASH;
  public const string EXEC_NAME;
  public const string USER_PROGRAM_NAME;
}
