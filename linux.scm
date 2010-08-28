;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;This program is distributed under the terms of the       ;;;
;;;GNU General Public License.                              ;;;
;;;Copyright (C) 2010 David Joseph Stith                    ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;Linux Kernel Interface;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;(call number goes in eax.
;;Up to 5 arguments go in ebx, ecx, edx, esi, edi)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;Linux Interface Constants;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define STDIN 0)
(define STDOUT 1)
(define STDERR 2)
(define O_RDONLY 0)
(define O_WRONLY 1)
(define O_CREAT 64)
(define O_TRUNC 512)
(define GENERIC_READ O_RDONLY)
(define GENERIC_WRITE (+ O_WRONLY O_CREAT O_TRUNC))

;;;;;;;;;;;;;;;;;;;;;
;;;Syscall Numbers;;;
;;;;;;;;;;;;;;;;;;;;;

;int sys_exit(int status)
(define SYS_EXIT 1)

;ssize_t sys_read(unsigned int fd, char* buf, size_t count)
(define SYS_READ 3)

;ssize_t sys_write(unsigned int fd, const char* buf, size_t count)
(define SYS_WRITE 4)

;int sys_open(const char* filename, int flags, int mode)
(define SYS_OPEN 5)

;sys_close(unsigned int fd)
(define SYS_CLOSE 6)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (exit-with-code x)
  (mov x ebx)
  (mov SYS_EXIT eax)
  (int #x80))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;Initialize Default Input and Output Ports;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(: 'initialize_ports)
  (mov (object INPUT_PORT STDIN) (@ 'current_input_port))
  (add 8 FREE)
  (mov (object OUTPUT_PORT STDOUT) (@ 'current_output_port))
  (add 8 FREE)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;Load Files Specified on Command-Line;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(: 'parse_command_line)
  (lea (@ 12 SP) TEMP)
  (cmp 0 (@ TEMP))
  (jnz 'command_line_begin)
  (ret)
(: 'command_line_begin)
  (mov 'exit_not_ok (@ 'error_continuation))
(: 'command_line_loop)
  (push TEMP)
  (mov (@ TEMP) TEMP)
  (call 'prim_load_scratch)
  (pop TEMP)
  (add 4 TEMP)
  (cmp 0 (@ TEMP))
  (jnz 'command_line_loop)
  (exit-with-code 0)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Read one character from file given in io_file (tetra) and place
;;character in input (tetra).
(: 'getch)
  (pusha)
  (mov 0 (@ 'input))
  (mov (@ 'io_file) ebx) ;File descriptor
  (mov 'input ecx)       ;Buffer
  (mov 1 edx)            ;Count
  (mov SYS_READ eax)
  (int #x80)
  (test eax eax)
  (jz 'getch_eof)
  (ifs (mov eax (@ 'input)))
  (popa)
  (ret)

(: 'getch_eof)
  (mov -1 (@ 'input))
  (popa)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Display character in output (byte) to file given in io_file (tetra)
(: 'putch)
  (pusha)
  (mov (@ 'io_file) ebx) ;File descriptor
  (mov 'output ecx)      ;Buffer
  (mov 1 edx)            ;Count
  (mov SYS_WRITE eax)
  (int #x80)
  (test eax eax)
  (jsl 'error_io)
  (popa)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Display string at ecx with length in str_len to file given in io_file (tetra)
(: 'puts)
  (pusha)
  (mov (@ 'io_file) ebx) ;File descriptor
  (mov (@ 'str_len) edx) ;Count
  (mov SYS_WRITE eax)
  (int #x80)
  (test eax eax)
  (jsl 'error_io)
  (popa)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Open file whose path is at ecx using flags in io_file (tetra).
;;Place descriptor in io_file
(: 'open_file)
  (pusha)
  (mov ecx ebx) ;Filename
  ;(add (@ 'str_len) ecx)
  ;(movb 0 (@ ecx))
  (mov (@ 'io_file) ecx) ;Flags
  (mov #o666 edx) ;Mode
  (mov SYS_OPEN eax)
  (int #x80)
  (test eax eax)
  (jsl 'error_io)
  (mov eax (@ 'io_file))
  (popa)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Close file whose descriptor is ecx
(: 'close_file)
  (test ecx ecx)
  (ifns
    (begin
      (pusha)
      (mov ecx ebx)
      (mov SYS_CLOSE eax)
      (int #x80)
      (cmp -1 eax)
      (jel 'error_io)
      (popa)))
  (ret)

;;;;;;;;;;;;;;;;;;;;;;
;;;Linux Primitives;;;
;;;;;;;;;;;;;;;;;;;;;;

(define regops (list ebx ecx edx esi edi))
(define (bind-regops regs x)
  (if (pair? x)
    (let ((end_ops (symbol-seq))
          (t (car x))
          (r (car regs)))
      (if (eq? t 'OPTIONAL)
        (begin
          (clear r)
          (test VAL VAL)
          (jzl end_ops))
        (begin
          (test VAL VAL)
          (jzl 'linux_error_too_few_args)))
      (mov (@ VAL) r)
      (test r r)
      (ifnz
        (case t
          ((INTEGER OPTIONAL)
            (opd-size)(cmp INTEGER (@ r))
            (jnel 'linux_error_expected_exact_integer)
            (mov (@ 4 r) r))
          ((ADDRESS)
            (opd-size)(cmp INTEGER (@ r))
            (jnel 'linux_error_expected_exact_integer)
            (lea (@ 4 r) r))
          ((INPUT_PORT)
            (opd-size)(cmp INPUT_PORT (@ r))
            (jnel 'linux_error_expected_input_port)
            (mov (@ 4 r) r))
          ((OUTPUT_PORT)
            (opd-size)(cmp OUTPUT_PORT (@ r))
            (jnel 'linux_error_expected_output_port)
            (mov (@ 4 r) r))
          ((MUTABLE_STRING)
      	    (opd-size)(cmp MUTABLE_STRING (@ r))
            (jnel 'linux_error_expected_mutable_string)
            (mov (@ 4 r) r))
          ((STRING)
      	    (cmpb TYPE_STRING (@ r))
            (jnel 'linux_error_expected_string)
            (mov (@ 4 r) r))))
      (mov (@ 4 VAL) VAL)
      (: end_ops)
      (bind-regops (cdr regs) (cdr x)))))
(define (syscall num name . operands)
  (new-primitive name)
  (pusha)
  (if (<= (length operands) 5)
    (begin
      (mov ARGL VAL)
      (bind-regops regops operands)
      (test VAL VAL)
      (jnzl 'linux_error_too_many_args)
      (mov num eax))
    (begin
      (display "ERROR: I don't yet know how to handle >5 syscall operands.")
      (exit)))
  (int #x80)
  (if (> num 1) ;anything but sys-exit returns an INTEGER
    (begin
      (mov eax (@ 'backup))
      (popa)
      (mov (@ 'backup) TEMP)
      (mov (object INTEGER TEMP) VAL)
      (jmpl 'advance_free))))

(: 'linux_error_expected_exact_integer)
  (popa)
  (jmpl 'error_expected_exact_nonnegative_integer)
(: 'linux_error_expected_input_port)
  (popa)
  (jmpl 'error_expected_input_port)
(: 'linux_error_expected_output_port)
  (popa)
  (jmpl 'error_expected_output_port)
(: 'linux_error_expected_mutable_string)
  (popa)
  (jmpl 'error_expected_mutable_string)
(: 'linux_error_expected_string)
  (popa)
  (jmpl 'error_expected_string)
(: 'linux_error_too_many_args)
  (popa)
  (jmpl 'error_too_many_args)
(: 'linux_error_too_few_args)
  (popa)
  (jmpl 'error_too_few_args)

(new-primitive "exit")
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;     NUM NAME          OPERANDS                                          ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(syscall  1 "sys-exit"    'OPTIONAL)
(syscall  2 "sys-fork")
(syscall  3 "sys-read"    'INPUT_PORT 'MUTABLE_STRING 'INTEGER)
(syscall  4 "sys-write"   'OUTPUT_PORT 'STRING 'INTEGER)
(syscall  5 "sys-open"    'STRING 'INTEGER 'INTEGER)
(syscall  6 "sys-close"   'INTEGER)
(syscall  7 "sys-waitpid" 'INTEGER 'ADDRESS 'INTEGER)
(syscall  8 "sys-creat"   'STRING 'INTEGER)
(syscall  9 "sys-link"    'STRING 'STRING)
(syscall 10 "sys-unlink"  'STRING)
;(syscall 11 "sys-execve"  '???)
(syscall 12 "sys-chdir"   'STRING)
(syscall 13 "sys-time"    'ADDRESS)
(syscall 14 "sys-mknod"   'STRING 'INTEGER 'INTEGER)
(syscall 15 "sys-chmod"   'STRING 'INTEGER)
(syscall 16 "sys-lchown"  'STRING 'INTEGER 'INTEGER)
;syscall 17 "sys-break" is obsolete
;syscall 18 "sys-oldstat" is obsolete
(syscall 19 "sys-lseek"   'INTEGER 'INTEGER 'INTEGER)
(syscall 20 "sys-getpid")
(syscall 21 "sys-mount"   'STRING 'STRING 'STRING 'INTEGER 'INTEGER)
(syscall 22 "sys-umount"  'STRING)
(syscall 23 "sys-setuid"  'INTEGER)
(syscall 24 "sys-getuid")
(syscall 25 "sys-stime"   'ADDRESS)
(syscall 26 "sys-ptrace"  'INTEGER 'INTEGER 'INTEGER 'INTEGER)
(syscall 27 "sys-alarm"   'INTEGER)
(syscall 29 "sys-pause")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Dynamic Link Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "dlopen")
  (call 'get_last_string)
  (pusha)
  (push 1)
  (push (@ 4 ARGL))
  (calln (@ 'dlopen_rel))
  (add 8 esp)
  (mov eax (@ 'io_file))
  (popa)
  (mov (@ 'io_file) VAL)
  (mov (object INTEGER VAL) VAL)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "dlclose")
  (call 'get_last_exact_natural)
  (pusha)
  (push (@ 4 TEMP))
  (calln (@ 'dlclose_rel))
  (add 4 esp)
  (mov eax (@ 'io_file))
  (popa)
  (mov (@ 'io_file) VAL)
  (mov (object INTEGER VAL) VAL)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "dlsym")
  (insure-more-args ARGL)
  (call 'get_exact_natural)
  (mov TEMP VAL)
  (mov (@ 4 ARGL) ARGL)
  (call 'get_last_string)
  (pusha)
  (push (@ 4 ARGL))
  (push (@ 4 VAL))
  (calln (@ 'dlsym_rel))
  (add 8 esp)
  (mov eax (@ 'io_file))
  (popa)
  (mov (@ 'io_file) VAL)
  (mov (object INTEGER VAL) VAL)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "dlcall")
  (insure-more-args ARGL)
  (call 'get_exact_natural)
  (pusha)
  (mov esp (@ 'backup))
  (jmp 'dlcall_loop_begin)
(: 'dlcall_loop)
  (mov (@ ARGL) VAL)
  (test VAL VAL)
  (jz 'dlcall_null)
  (push (@ 4 VAL))
(: 'dlcall_loop_begin)
  (mov (@ 4 ARGL) ARGL)
  (test ARGL ARGL)
  (jnz 'dlcall_loop)
  (calln (@ 4 TEMP))
  (mov (@ 'backup) esp)
  (mov eax (@ 'io_file))
  (popa)
  (mov (@ 'io_file) VAL)
  (mov (object INTEGER VAL) VAL)
  (jmpl 'advance_free)
(: 'dlcall_null)
  (push 0)
  (jmp 'dlcall_loop_begin)
