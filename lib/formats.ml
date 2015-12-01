(** The Qubes wire protocol details. *)

open Utils

module type FRAMING = sig
  val header_size : int
  val body_size_from_header : Cstruct.t -> int
end

module Qrexec = struct
  cstruct msg_header {
    uint32_t ty;
    uint32_t len;
  } as little_endian

  cstruct peer_info {
    uint32_t version;
  } as little_endian

  cstruct exec_params {
    uint32_t connect_domain;
    uint32_t connect_port;
    (* rest of message is command line *)
  } as little_endian

  cstruct exit_status {
    (* XXX: size of message depends on native int size?? *)
    uint32_t return_code;
  } as little_endian

  type msg_type =
    [ `Exec_cmdline
    | `Just_exec
    | `Service_connect
    | `Trigger_service
    | `Connection_terminated
    | `Hello
    | `Data_stdin
    | `Data_stdout
    | `Data_stderr
    | `Data_exit_code ]

  let type_of_int = function
    | 0x190l -> `Data_stdin
    | 0x191l -> `Data_stdout
    | 0x192l -> `Data_stderr
    | 0x193l -> `Data_exit_code
    | 0x200l -> `Exec_cmdline
    | 0x201l -> `Just_exec
    | 0x202l -> `Service_connect
    | 0x210l -> `Trigger_service
    | 0x211l -> `Connection_terminated
    | 0x300l -> `Hello
    | x -> `Unknown x

  let int_of_type = function
    | `Data_stdin -> 0x190l
    | `Data_stdout -> 0x191l
    | `Data_stderr -> 0x192l
    | `Data_exit_code -> 0x193l
    | `Exec_cmdline -> 0x200l
    | `Just_exec -> 0x201l
    | `Service_connect -> 0x202l
    | `Trigger_service -> 0x210l
    | `Connection_terminated -> 0x211l
    | `Hello -> 0x300l
    | `Unknown x -> x

  module Framing = struct
    let header_size = sizeof_msg_header
    let body_size_from_header h = get_msg_header_len h |> Int32.to_int
  end
end

module GUI = struct
  cstruct gui_protocol_version {
    uint32_t version;
  } as little_endian

  cstruct msg_header {
    uint32_t ty;
    uint32_t window;
  } as little_endian

  cstruct xconf {
    uint32_t w;
    uint32_t h;
    uint32_t depth;
    uint32_t mem;
  } as little_endian

  module Framing = struct
    let header_size = sizeof_msg_header
    let body_size_from_header _h = raise (error "GUI: body_size_from_header: TODO")
  end
end

module QubesDB = struct
  cenum qdb_msg {
    QDB_CMD_READ;
    QDB_CMD_WRITE;
    QDB_CMD_MULTIREAD;
    QDB_CMD_LIST;
    QDB_CMD_RM;
    QDB_CMD_WATCH;
    QDB_CMD_UNWATCH;
    QDB_RESP_OK;
    QDB_RESP_ERROR_NOENT;
    QDB_RESP_ERROR;
    QDB_RESP_READ;
    QDB_RESP_MULTIREAD; 
    QDB_RESP_LIST; 
    QDB_RESP_WATCH;
  } as uint8_t

  cstruct msg_header {
    uint8_t ty;
    uint8_t path[64];
    uint8_t padding[3];
    uint32_t data_len;
    (* rest of message is data *)
  } as little_endian

  let make_msg_header ~ty ~path ~data_len =
    let msg = Cstruct.create sizeof_msg_header in
    set_msg_header_ty msg (qdb_msg_to_int ty);
    set_fixed_string (get_msg_header_path msg) path;
    Cstruct.memset (get_msg_header_padding msg) 0;
    set_msg_header_data_len msg (Int32.of_int data_len);
    msg

  module Framing = struct
    let header_size = sizeof_msg_header
    let body_size_from_header h = get_msg_header_data_len h |> Int32.to_int
  end
end
