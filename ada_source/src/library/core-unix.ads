--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../License.txt

with Interfaces.C.Strings;

package Core.Unix is

   package IC renames Interfaces.C;

   type Unix_Pipe is (named_pipe, unix_socket, something_else);
   type Unix_Socket_Result is (connected, failed_creation, failed_population, failed_connection);

   type File_Descriptor is new Integer;
   not_connected : constant File_Descriptor := 1;

   --  strerror from libc
   function strerror (errno : Integer) return String;

   --  call C function to determine if FIFO or Socket or something else
   function IPC_mechanism (filename : String) return Unix_Pipe;

   --  Use libc's open function to retrieve file descriptor
   function open_file (filename : String; WRONLY, NON_BLOCK : Boolean) return File_Descriptor;

   --  Last seen error number by C function
   function errno return Integer;

   --  Connect to Unix-style socket
   function connect_unix_socket (filename : String; fd : out File_Descriptor)
                                 return Unix_Socket_Result;

   --  Return True if fd /= -1
   function file_connected (fd : File_Descriptor) return Boolean;

   --  Return True if file was successfully closed
   function close_file (fd : File_Descriptor) return Boolean;

private

   last_errno : Integer;

   function C_Strerror (Errnum : IC.int) return IC.Strings.chars_ptr;
   pragma Import (C, C_Strerror, "strerror");

   function C_Close (fd : IC.int) return IC.int;
   pragma Import (C, C_Close, "close");

   function C_Errno return IC.int;
   pragma Import (C, C_Errno, "get_errno");

   function C_Open (path : IC.Strings.chars_ptr;
                    wronly : IC.int;
                    nonblock : IC.int) return IC.int;
   pragma Import (C, C_Open, "try_open");

   function C_IPC (path : IC.Strings.chars_ptr) return IC.int;
   pragma Import (C, C_IPC, "detect_IPC");

   function C_Connect (path  : IC.Strings.chars_ptr;
                       newfd : out IC.int) return IC.int;
   pragma Import (C, C_Connect, "connect_socket");

   function success (rc : IC.int) return Boolean;

end Core.Unix;
