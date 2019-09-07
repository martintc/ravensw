--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../License.txt

with Ada.Containers.Vectors;

with Core.Pkg;     use Core.Pkg;
with Core.Strings; use Core.Strings;
with Core.Unix;

package Core.Checksum is

   package CON renames Ada.Containers;

   function pkg_checksum_type_from_string (name : String) return T_checksum_type;

   function pkg_checksum_type_to_string (checksum_type : T_checksum_type) return String;

   function pkg_checksum_is_valid (cksum : Text) return Boolean;

   function pkg_checksum_file (path : String; checksum_type : T_checksum_type) return String;

   function pkg_checksum_fd
     (fd : Unix.File_Descriptor;
      checksum_type : T_checksum_type)
      return String;


private

   PKG_CKSUM_SEPARATOR      : constant String (1 .. 1) := "$";
   PKG_CHECKSUM_CUR_VERSION : constant Integer := 2;

   type pkg_checksum_entry is
      record
         field : Text;
         value : Text;
      end record;

   package checksum_entry_crate is new CON.Vectors
     (Element_Type => pkg_checksum_entry,
      Index_Type   => Natural);





   function pkg_checksum_hash_sha256  (entries : checksum_entry_crate.Vector) return String;
   function pkg_checksum_hash_blake2  (entries : checksum_entry_crate.Vector) return String;
   function pkg_checksum_hash_blake2s (entries : checksum_entry_crate.Vector) return String;

   function pkg_checksum_hash_file         (fd : Unix.File_Descriptor;
                                            checksum_type : T_checksum_type) return String;
   function pkg_checksum_hash_sha256_file  (fd : Unix.File_Descriptor) return String;
   function pkg_checksum_hash_blake2_file  (fd : Unix.File_Descriptor) return String;
   function pkg_checksum_hash_blake2s_file (fd : Unix.File_Descriptor) return String;

   function pkg_checksum_encode        (plain : String;
                                        checksum_type : T_checksum_type) return String;
   function pkg_checksum_encode_base32 (plain : String) return String;
   function pkg_checksum_encode_hex    (plain : String) return String;

end Core.Checksum;
