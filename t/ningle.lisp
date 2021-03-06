#|
  This file is a part of ningle project.
  Copyright (c) 2012 Eitarow Fukamachi (e.arrows@gmail.com)
|#

(in-package :cl-user)
(defpackage ningle-test
  (:use :cl
        :ningle
        :cl-test-more)
  (:import-from :clack.request
                :<request>)
  (:import-from :clack.response
                :headers
                :body)
  (:import-from :clack.test
                :test-app
                :*clack-test-port*)
  (:import-from :babel
                :octets-to-string)
  (:import-from :drakma
                :http-request)
  (:import-from :yason
                :parse))
(in-package :ningle-test)

(plan 19)

(defvar *app*)
(setf *app* (make-instance '<app>))

(ok (not (route *app* "/")))

(setf (route *app* "/")
      (lambda (params)
        (declare (ignore params))
        "Hello, World!"))

(ok (route *app* "/"))
(ok (not (route *app* "/" :method :POST)))

(setf (route *app* "/post" :method :POST)
      (lambda (params)
        (declare (ignore params))
        "posted"))

(ok (not (route *app* "/post")))
(ok (route *app* "/post" :method :POST))

(setf (route *app* "/new" :method '(:GET :POST))
      (lambda (params)
        (declare (ignore params))
        "new"))
(ok (route *app* "/new" :method '(:GET :POST)))

(setf (route *app* "/testfile")
      (lambda (params)
        (declare (ignore params))
        (asdf:system-relative-pathname :ningle-test #P"t/test.html")))

(setf (route *app* "/hello.json")
      (lambda (params)
        (declare (ignore params))
        '(200 (:content-type "application/json") ("{\"text\":\"Hello, World!\"}"))))

(setf (route *app* "/hello2.json")
      (lambda (params)
        (declare (ignore params))
        (setf (headers *response* :content-type)
              "application/json")
        "{\"text\":\"Hello, World!\"}"))

(defun say-hello (params)
  (format nil "Hello, ~A" (getf params :|name|)))

(setf (route *app* "/hello")
      'say-hello)

(setf (route *app* "/hello" :identifier 'say-hello)
      #P"hello.html")

(is (route *app* "/hello") 'say-hello)
(is (route *app* "/hello" :identifier 'say-hello) #P"hello.html")

(flet ((localhost (path)
         (format nil "http://localhost:~D~A" clack.test:*clack-test-port* path)))
  (clack.test:test-app
   *app*
   (lambda ()
     (is (drakma:http-request (localhost "/")) "Hello, World!")
     (loop for url in '("/hello.json" "/hello2.json")
           do (multiple-value-bind (body status headers)
                  (drakma:http-request (localhost url))
                (is status 200)
                (is (cdr (assoc :content-type headers))
                    "application/json")
                (is (gethash "text" (yason:parse (babel:octets-to-string body)))
                    "Hello, World!")))
     (is (nth-value 1 (drakma:http-request (localhost "/testfile"))) 200
         "Can return a pathname.")

     (is (drakma:http-request (localhost "/hello?name=Eitarow"))
         "Hello, Eitarow"
         "Allow a symbol for a controller."))))

(defclass ningle-test-app (<app>) ())
(defclass ningle-test-request (<request>) ())
(defmethod make-request ((app ningle-test-app) env)
  (apply #'make-instance 'ningle-test-request
         :allow-other-keys t
         env))

(defvar *app2*)
(setf *app2* (make-instance 'ningle-test-app))

(setf (route *app2* "/request-class")
      (lambda (params)
        (declare (ignore params))
        (prin1-to-string (class-name (class-of *request*)))))

(clack.test:test-app
 *app2*
 (lambda ()
   (is (drakma:http-request (format nil "http://localhost:~D/request-class"
                                    clack.test:*clack-test-port*))
       (format nil "~A::~A"
               :ningle-test
               :ningle-test-request)
       "Can change the class of request.")))

(defmethod not-found ((this ningle-test-app))
  (setf (clack.response:body *response*) "Page not found")
  nil)

(clack.test:test-app
 *app2*
 (lambda ()
   (is (drakma:http-request (format nil "http://localhost:~D/404-page-not-found"
                                    clack.test:*clack-test-port*))
       "Page not found"
       "Can change the behavior on 404")))

(finalize)
