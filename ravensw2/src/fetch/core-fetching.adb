--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../../License.txt

with Ada.Environment_Variables;

with Core.Pkgtypes;
with Core.Strings;
with Core.Config;
with Core.Event;
with Libfetch;

use Core.Strings;

package body Core.Fetching is

   package ENV renames Ada.Environment_Variables;

   --------------------------------------------------------------------
   --  fetch_file_to_fd
   --------------------------------------------------------------------
   function fetch_file_to_fd
     (my_repo   : Repo.A_repo;
      file_url  : String;
      dest_fd   : Unix.File_Descriptor;
      timestamp : Unix.T_epochtime;
      offset    : Unix.T_filesize;
      filesize  : Unix.T_filesize) return Action_Result
   is
      procedure set_env (position : Pkgtypes.Package_NVPairs.Cursor);
      procedure restore_env (position : Pkgtypes.Package_NVPairs.Cursor);

      max_retry     : constant int64 := Config.configuration_value (Config.fetch_retry);
      fetch_timeout : constant int64 := Config.configuration_value (Config.fetch_timeout);
      retry         : int64 := max_retry;

      URL_SCHEME_PREFIX : constant String := "pkg+";
      pkg_url_scheme    : Boolean;
      new_url           : Text;

      env_to_unset      : Pkgtypes.Text_Crate.Vector;
      env_to_restore    : Pkgtypes.Package_NVPairs.Map;

      url_components    : Libfetch.URL_Component_Set;

      procedure set_env (position : Pkgtypes.Package_NVPairs.Cursor)
      is
         text_key : Text renames Pkgtypes.Package_NVPairs.Key (position);
         text_val : Text renames Pkgtypes.Package_NVPairs.Element (position);
         env_key  : String := USS (text_key);
         env_val  : String := USS (text_val);
      begin
         if ENV.Exists (env_key) then
            env_to_restore.Insert (text_key, SUS (ENV.Value (env_key)));
         else
            env_to_unset.Append (text_key);
         end if;
         env.Set (env_key, env_val);
      end set_env;

      procedure restore_env (position : Pkgtypes.Package_NVPairs.Cursor)
      is
         procedure unset (position : Pkgtypes.Text_Crate.Cursor);
         procedure restore (position : Pkgtypes.Package_NVPairs.Cursor);

         procedure unset (pos2 : Pkgtypes.Text_Crate.Cursor)
         is
            key : String := USS (Pkgtypes.Package_NVPairs.Element (pos2));
         begin
            ENV.Clear (key);
         end unset;

         procedure restore (pos2 : Pkgtypes.Package_NVPairs.Cursor)
         is
            env_key  : String := USS (Pkgtypes.Package_NVPairs.Key (pos2));
            env_val  : String := USS (Pkgtypes.Package_NVPairs.Element (pos2));
         begin
            ENV.Set (env_key, env_val);
         end restore;
      begin
         env_to_unset.iterate (unset'Access);
         env_to_restore.Iterate (restore'Access);
      end restore_env;
   begin

      --  /* A URL of the form http://host.example.com/ where
      --   * host.example.com does not resolve as a simple A record is
      --   * not valid according to RFC 2616 Section 3.2.2.  Our usage
      --   * with SRV records is incorrect.  However it is encoded into
      --   * /usr/sbin/pkg in various releases so we can't just drop it.
      --   *
      --   * Instead, introduce new pkg+http://, pkg+https://,
      --   * pkg+ssh://, pkg+ftp://, pkg+file:// to support the
      --   * SRV-style server discovery, and also to allow eg. Firefox
      --   * to run pkg-related stuff given a pkg+foo:// URL.
      --   *
      --   * Error if using plain http://, https:// etc with SRV
      --   */

      if leads (file_url, URL_SCHEME_PREFIX) then
         case Repo.repo_mirror_type (my_repo) is
            when Repo.SRV => null;
            when Repo.HTTP | Repo.NOMIRROR =>
               Event.emit_error ("packagesite URL error for " & file_url
                                 & " -- " & URL_SCHEME_PREFIX
                                 &  ":// implies SRV mirror type");
               return RESULT_FATAL;
         end case;
         pkg_url_scheme := True;
         new_url := SUS (part_2 (file_url, URL_SCHEME_PREFIX));
      else
         pkg_url_scheme := False;
         new_url := SUS (file_url);
      end if;

      Repo.repo_environment (my_repo).Iterate (set_env'Access);

      url_components := Libfetch.parse_url (USS (new_url));
      if not Libfetch.url_is_valid (url_components) then
         Event.emit_error (USS (new_url) & ": parse error");
         Repo.repo_environment (my_repo).Iterate (restore_env'Access);
         return RESULT_FATAL;
      end if;

      Libfetch.provide_last_timestamp (timestamp, url_components);

      if Libfetch.url_scheme (url_components) = "ssh" then
      end if;

   end fetch_file_to_fd;

end Core.Fetching;
