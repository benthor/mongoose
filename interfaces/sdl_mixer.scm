;;;;;;;;;;;;;;;;;;;
;;; Dll Modules ;;;
;;;;;;;;;;;;;;;;;;;

;(define *mix-path* "sdl_mixer") ;Should be "libSDL_mixer-1.2.so.0" on Linux
(define *mix* (dlopen *mix-path*))
(if (zero? *mix*) (error "Could not open SDL_mixer library"))

(define MIX_DEFAULT_FREQUENCY 22050)

;;;;;;;;;;;;;;;;;
;;; Functions ;;;
;;;;;;;;;;;;;;;;;

(define mix-open-audio
  (let ((f (dlsym *mix* "Mix_OpenAudio")))
    (lambda (rate format channels buffers)
      (dlcall f buffers channels format rate))))

(define mix-close-audio
  (let ((f (dlsym *mix* "Mix_CloseAudio")))
    (lambda ()
      (dlcall f))))

(define mix-load-wav-rw
  (let ((f (dlsym *mix* "Mix_LoadWAV_RW")))
    (lambda (src freesrc)
      (dlcall f freesrc src))))

(define mix-load-mus
  (let ((f (dlsym *mix* "Mix_LoadMUS")))
    (lambda (file)
      (dlcall f file))))

(define mix-play-channel-timed
  (let ((f (dlsym *mix* "Mix_PlayChannelTimed")))
    (lambda (channel chunk loops ticks)
      (dlcall f ticks loops chunk channel))))

(define mix-play-music
  (let ((f (dlsym *mix* "Mix_PlayMusic")))
    (lambda (music loops)
      (dlcall f loops music))))

(define mix-halt-channel
  (let ((f (dlsym *mix* "Mix_HaltChannel")))
    (lambda (channel)
      (dlcall f channel))))

(define mix-halt-music
  (let ((f (dlsym *mix* "Mix_HaltMusic")))
    (lambda ()
      (dlcall f))))

(define mix-free-music
  (let ((f (dlsym *mix* "Mix_FreeMusic")))
    (lambda (music)
      (dlcall f music))))

(define mix-pause
  (let ((f (dlsym *mix* "Mix_Pause")))
    (lambda (channel)
      (dlcall f channel))))

(define mix-resume
  (let ((f (dlsym *mix* "Mix_Resume")))
    (lambda (channel)
      (dlcall f channel))))

;;;;;;;;;;;;;;;
;;; Helpers ;;;
;;;;;;;;;;;;;;;
(define (mix-load-wav file)
  (mix-load-wav-rw (sdl-rw-from-file file "rb") 1))
(define (mix-play-channel channel chunk loops)
  (mix-play-channel-timed channel chunk loops -1))
