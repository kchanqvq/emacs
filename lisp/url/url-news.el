;;; url-news.el --- News Uniform Resource Locator retrieval code

;; Copyright (C) 1996-1999, 2004-2020 Free Software Foundation, Inc.

;; Keywords: comm, data, processes

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Code:

(require 'url-vars)
(require 'url-util)
(require 'url-parse)
(require 'nntp)
(autoload 'url-warn "url")
(autoload 'gnus-group-read-ephemeral-group "gnus-group")

;; Unused.
;;; (defgroup url-news nil
;;;   "News related options."
;;;   :group 'url)

(defun url-news-open-host (host port user pass)
  (if (fboundp 'nnheader-init-server-buffer)
      (nnheader-init-server-buffer))
  (nntp-open-server host (list port))
  (if (and user pass)
      (progn
	(nntp-send-command "^.*\r?\n" "AUTHINFO USER" user)
	(nntp-send-command "^.*\r?\n" "AUTHINFO PASS" pass)
	(if (not (nntp-server-opened host))
	    (url-warn 'url (format "NNTP authentication to `%s' as `%s' failed"
				   host user))))))

(defun url-news-fetch-message-id (host message-id)
  (let ((buf (generate-new-buffer " *url-news*")))
    (if (eq ?> (aref message-id (1- (length message-id))))
	nil
      (setq message-id (concat "<" message-id ">")))
    (if (cdr-safe (nntp-request-article message-id nil host buf))
	;; Successfully retrieved the article
	nil
      (with-current-buffer buf
	(insert "Content-type: text/html\n\n"
		"<html>\n"
		" <head>\n"
		"  <title>Error</title>\n"
		" </head>\n"
		" <body>\n"
		"  <div>\n"
		"   <h1>Error requesting article...</h1>\n"
		"   <p>\n"
		"    The status message returned by the NNTP server was:"
		"<br><hr>\n"
		"    <xmp>\n"
		(nntp-status-message)
		"    </xmp>\n"
		"   </p>\n"
		"   <p>\n"
		"    If you feel this is an error, M-x report-emacs-bug RET.\n"
		"   </p>\n"
		"  </div>\n"
		" </body>\n"
		"</html>\n"
                "<!-- Automatically generated by URL in Emacs " emacs-version " -->\n"
		)))
    buf))

(defvar gnus-group-buffer)

(defun url-news-fetch-newsgroup (newsgroup host)
  (if (string-match "^/+" newsgroup)
      (setq newsgroup (substring newsgroup (match-end 0))))
  (if (string-match "/+$" newsgroup)
      (setq newsgroup (substring newsgroup 0 (match-beginning 0))))

  ;; This saves us from checking new news if Gnus is already running
  ;; FIXME - is it relatively safe to use gnus-alive-p here? FIXME
  (if (or (not (get-buffer gnus-group-buffer))
	  (with-current-buffer gnus-group-buffer
	    (not (eq major-mode 'gnus-group-mode))))
      (gnus))
  (set-buffer gnus-group-buffer)
  (goto-char (point-min))
  (gnus-group-read-ephemeral-group newsgroup
				   (list 'nntp host
					 (list 'nntp-open-connection-function
					       nntp-open-connection-function))
				   nil
				   (cons (current-buffer) 'browse)))

;;;###autoload
(defun url-news (url)
  ;; Find a news reference
  (let* ((host (or (url-host url) url-news-server))
	 (port (url-port url))
	 (article-brackets nil)
	 (buf nil)
	 (article (url-unhex-string (url-filename url))))
    (url-news-open-host host port (url-user url) (url-password url))
    (cond
     ((string-match "@" article)	; Its a specific article
      (setq buf (url-news-fetch-message-id host article)))
     ((string= article "")		; List all newsgroups
      (gnus))
     (t					; Whole newsgroup
      (url-news-fetch-newsgroup article host)))
    buf))

;;;###autoload
(defun url-snews (url)
  (let ((nntp-open-connection-function (if (eq 'ssl url-gateway-method)
					   'nntp-open-ssl-stream
					 'nntp-open-tls-stream)))
    (url-news url)))

(provide 'url-news)

;;; url-news.el ends here