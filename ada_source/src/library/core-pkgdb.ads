--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../License.txt

with Interfaces.C.Strings;
with sqlite_h;
with regex_h;
with System;

package Core.PkgDB is

   package IC  renames Interfaces.C;
   package ICS renames Interfaces.C.Strings;

   procedure pkgshell_open (reponame : access ICS.chars_ptr);
   pragma Export (C, pkgshell_open);

   procedure pkgdb_command (passthrough : String);

private

   case_sensitivity_setting : Boolean := False;

   --  By default, MATCH_EXACT and MATCH_REGEX are case sensitive.  This
   --  is modified in many actions according to the value of
   --  CASE_SENSITIVE_MATCH in ravensw.conf and then possibly reset again in
   --  pkg search et al according to command line flags
   procedure pkgdb_set_case_sensitivity (sensitive : Boolean);
   function  pkgdb_is_case_sensitive return Boolean;

   --  regex object must be global to assign access to it.
   re : aliased regex_h.regex_t;

   --  Defines custom sql functions for sqlite
   function pkgdb_sqlcmd_init
     (db       : not null sqlite_h.sqlite3_Access;
      pzErrMsg : not null access ICS.chars_ptr;
      pThunk   : not null sqlite_h.sqlite3_api_routines_Access) return IC.int;
   pragma Export (C, pkgdb_sqlcmd_init);

   --  select now();
   --  returns 1567046088
   --
   --  takes no arguments
   --  Function returns unix epoch as defined by system clock
   procedure pkgdb_now
     (context : not null sqlite_h.sqlite3_context_Access;
      numargs : IC.int;
      argsval : not null access sqlite_h.sqlite3_value_Access);
   pragma Convention (C, pkgdb_now);

   --  select myarch();
   --  returns "DragonFly:5.8:x86_64"
   --  select myarch(null);
   --  returns "DragonFly:5.8:x86_64"
   --  select myarch("OpenBSD:6.4:amd64");
   --  returns "OpenBSD:6.4:amd64";
   --
   --  arg1 optional.  Will override ABI if present
   --  Function returns configured ABI unless overridden in arguments (then it returns that)
   procedure pkgdb_myarch
     (context : not null sqlite_h.sqlite3_context_Access;
      numargs : IC.int;
      argsval : not null access sqlite_h.sqlite3_value_Access);
   pragma Convention (C, pkgdb_myarch);

   --  sqlite> select regexp ("[0-9]e", "abc3ef");
   --  returns 1
   --  sqlite> select regexp ("[0-9]f", "abc3ef");
   --  returns 0
   --
   --  arg1 = regular expression string
   --  arg2 = input string
   --  returns 0 (false) or 1 (true) if a match is found
   --  Function returns True if given string has a match against given regular expression
   procedure pkgdb_regex
     (context : not null sqlite_h.sqlite3_context_Access;
      numargs : IC.int;
      argsval : not null access sqlite_h.sqlite3_value_Access);
   pragma Convention (C, pkgdb_regex);

   --  select split_version ("name", "joe-1.0");
   --  returns "joe"
   --  select split_version ("version", "joe-1.0_1,2");
   --  returns "1.0_1,2"
   --
   --  arg1 = "name" or "version"
   --  arg2 = package name
   --  function returns name part or version part of package name
   procedure pkgdb_split_version
     (context : not null sqlite_h.sqlite3_context_Access;
      numargs : IC.int;
      argsval : not null access sqlite_h.sqlite3_value_Access);
   pragma Convention (C, pkgdb_split_version);

   --  select vercmp("<=", "joe-1.0", "joe-1.1");
   --  returns 1.
   --
   --  arg1 = operator string ("==", "!=", "<", ">", "<=", ">=", anything else)
   --  arg2 = package 1 name
   --  arg3 = package 2 name
   --  Function compares package 2 name against package 1 name and returns 0 or 1.
   procedure pkgdb_vercmp
     (context : not null sqlite_h.sqlite3_context_Access;
      numargs : IC.int;
      argsval : not null access sqlite_h.sqlite3_value_Access);
   pragma Convention (C, pkgdb_vercmp);

   --  callback for pkgdb_regex
   procedure pkgdb_regex_delete (regex_ptr : not null regex_h.regex_t_Access);
   pragma Convention (C, pkgdb_regex_delete);

   --  Converts boolean until C integer
   function conv2cint (result : Boolean) return IC.int;

   --  Where split routine does the actual work (allows custom split words, delimiter, etc)
   procedure pkgdb_split_common
     (context : not null sqlite_h.sqlite3_context_Access;
      numargs : IC.int;
      argsval : not null access sqlite_h.sqlite3_value_Access;
      delim   : Character;
      first   : String;
      second  : String);

end Core.PkgDB;
