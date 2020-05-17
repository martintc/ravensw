--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../License.txt

package Core.Utilities is

   subtype hexrep is String (1 .. 2);

   --  unlike realpath(3), this routine does not expand symbolic links
   function pkg_absolutepath (input_path : String; fromroot : Boolean) return String;

   --  Converts an 8-bit character to a 2-digit lower-case hex string
   function char2hex (quattro : Character) return hexrep;

   --  String leading forward slash if it exists
   function relative_path (input_path : String) return String;

   --  Converts a 2-hexchar string into an ascii character
   --  hexchar must contain 0-9,A-F,a-f on both characters.  If not, return NUL character
   function hex2char (hex : hexrep) return Character;

   --  Given a value, format with "kB", "MB", "GB", "TB", prefixes as necessary (power 10)
   function format_bytes_SI (bytes : int64) return String;

   --  Given a value, format with "KiB", "MiB", "GiB", "TiB", prefixes as necessary (power 2)
   function format_bytes_IEC (bytes : int64) return String;

end Core.Utilities;
