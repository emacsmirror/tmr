;;; tmr-tabulated.el --- Display timers in a tabulated list -*- lexical-binding: t -*-

;; Copyright (C) 2020-2022  Free Software Foundation, Inc.

;; Author: Damien Cassou <damien@cassou.me>,
;;         Protesilaos Stavrou <info@protesilaos.com>
;; Maintainer: Protesilaos Stavrou <info@protesilaos.com>
;; URL: https://git.sr.ht/~protesilaos/tmr
;; Mailing list: https://lists.sr.ht/~protesilaos/tmr
;; Version: 0.3.0
;; Package-Requires: ((emacs "27.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Call `M-x tmr-tabulated-view' to display all tmr timers in a grid,
;; one by line with sortable columns.  Columns show the creation date,
;; the end date, a check mark if the timer is finished and the timer's
;; optional description.
;;
;; Please read the manual for all the technicalities.  Either evaluate
;; (info "(tmr) Top") or visit <https://protesilaos.com/emacs/tmr>.

;;; Code:

(require 'tmr)

;;;###autoload
(defun tmr-tabulated-view ()
  "Open a tabulated list buffer listing tmr timers."
  (interactive)
  (switch-to-buffer (get-buffer-create "*tmr-tabulated-view*"))
  (tmr-tabulated--set-entries)
  (tmr-tabulated-mode)
  (tabulated-list-print))

(defun tmr-tabulated--set-entries ()
  "Set the value of `tabulated-list-entries' with timers."
  (setq-local tabulated-list-entries
              (mapcar #'tmr-tabulated--timer-to-entry tmr--timers)))

(defun tmr-tabulated--timer-to-entry (timer)
  "Convert TIMER into an entry suitable for `tabulated-list-entries'."
  (list (tmr--timer-creation-date timer)
        (vector (tmr--format-creation-date timer)
                (tmr--format-end-date timer)
                (if (tmr--timer-donep timer) "???" "")
                (or (tmr--timer-description timer) ""))))

(defvar tmr-tabulated-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "k" #'tmr-tabulated-cancel)
    (define-key map "K" #'tmr-tabulated-remove-finished)
    (define-key map "+" #'tmr)
    (define-key map "c" #'tmr-tabulated-clone)
    (define-key map "w" #'tmr-tabulated-rewrite-description)
    (define-key map "s" #'tmr-tabulated-reschedule)
    map)
  "Keybindings for `tmr-tabulated-mode-map'.")

(define-derived-mode tmr-tabulated-mode tabulated-list-mode "TMR"
  "Major mode to display tmr timers."
  (setq-local tabulated-list-format
              [("Start" 10 t)
               ("End" 10 t)
               ("Finished?" 10 t)
               ("Description" 0 t)])
  (add-hook 'tabulated-list-revert-hook #'tmr-tabulated--set-entries nil t)
  (tabulated-list-init-header))

(defun tmr-tabulated-cancel (timer &optional no-hooks)
  "Stop TIMER and remove it from the list.
Interactively, use the timer at point.

Optional NO-HOOKS has the same meaning as in `tmr-cancel'."
  (interactive (list (tmr-tabulated--get-timer-at-point) current-prefix-arg))
  (tmr-cancel timer no-hooks)
  ;; avoid point moving back to the beginning of the buffer:
  (tmr-tabulated--move-point-to-closest-entry)
  (revert-buffer))

(defun tmr-tabulated-remove-finished ()
  "Remove all finished timers."
  (interactive)
  (tmr-remove-finished)
  (revert-buffer))

(defun tmr-tabulated-clone (timer)
  "Create a new timer by cloning TIMER.
Interactively, use the timer at point."
  (interactive (list (tmr-tabulated--get-timer-at-point)))
  (tmr-clone timer)
  (revert-buffer))

(defun tmr-tabulated-reschedule (timer)
  "Reschedule TIMER.
This is the same as cloning it and cancelling the original one.

If TIMER has a description, prompt for one.  Otherwise only
prompt for a duration."
  (interactive (list (tmr-tabulated--get-timer-at-point)))
  (tmr-clone timer :prompt)
  ;; Cancel the old timer
  (tmr-tabulated-cancel timer :no-hooks))

(defun tmr-tabulated-rewrite-description (timer description)
  "Change TIMER description with that of DESCRIPTION."
  (interactive
   (list
    (tmr-tabulated--get-timer-at-point)
    (tmr--description-prompt)))
  (setf (tmr--timer-description timer) description)
  (revert-buffer))

(defun tmr-tabulated--move-point-to-closest-entry ()
  "Move the point to the next entry if there is one or to the previous one.
Point isn't moved if point is on the only entry."
  (if (tmr-tabulated--next-entry)
      (forward-line 1)
    (when (tmr-tabulated--previous-entry)
      (forward-line -1))))

(defun tmr-tabulated--previous-entry ()
  "Return the entry on the line before point, nil if none."
  (save-excursion
    (setf (point) (line-beginning-position))
    (unless (bobp)
      (forward-line -1)
      (tabulated-list-get-id))))

(defun tmr-tabulated--next-entry ()
  "Return the entry on the line after point, nil if none."
  (save-excursion
    (setf (point) (line-end-position))
    (unless (eobp)
      (forward-line 1)
      (tabulated-list-get-id))))

(defun tmr-tabulated--get-timer-at-point ()
  "Return the timer on the current line or nil."
  (tmr--get-timer-by-creation-date (tabulated-list-get-id)))

(provide 'tmr-tabulated)
;;; tmr-tabulated.el ends here
