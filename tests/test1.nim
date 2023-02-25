import unittest
import silogue

type User = object
  name: string
  age: int

var app = genApp()

routes:
  "/":
    get "name:string":  # This is a query parameter
      # By default, resp responds in HTML
      resp "<h1>Hello " & name & "</h1>"
  "/optional":
    # ? Mark for optional values
    # It returns an Option
    # Read using val.get(defaultVal)
    # isSome and isNone check if something was given
    get "name:string?":
      if name.isSome:
        resp "<h1>Hello " & name.get() & "</h1>"
      else:
        resp "<h1>Hello anonymous!</h1>"
  "/json-no-schema":
    get:
      # Send a fake user back
      let newUser = User(name: "SmortBoi", age: 2)
      # % returns a JSONNode,
      # respjson responds to the client with JSON      
      respjson %newUser
    post "time:string" json"user":
      var res = "You really shouldn't use JSON without a schema,"
      res &= "but I incorporated this feature incase it was needed."
      res &= "Your name is "
      if user.hasKey("name"):
        res &= user["name"].getStr() & "!\n"
        res &= "Don't give out your name to random websites!!"
      else:
        res &= "anonymous.\n"
        res &= "That's a good thing to do on the web"
      resptext res
      # We can tell resp to respond with plaintext instead of HTML
  "/json-with-schema/{times:int}":
    # Use {} for path parameters
    post json"user:User":
      # POST data in JSON with User Schema
      var res = ""
      for i in 1..times:
        res &= user.name & " is " & $user.age & " years old!\n"
      resptext res