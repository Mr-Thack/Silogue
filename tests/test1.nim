import unittest
import silogue

var app = genApp()

routes:
  "/":
    get "name:string":
      resp "Hello " & name    
    post:
      resp "Posted"
  "/hello":
    get:
      resp "Lolol"
  "/eat":
    get "food:string&times:int":
      var res = ""
      for i in 0..times:
        res &= "You would like to eat " & food & "\n"
      resp plainTextResponse(res)