# Simple Prologue
I'm attempting to form it into a truly simple framework.
So simple, that even an idiot could reliably use it.

# Demonstration:
*Please Note that this is just a backend example*\
*Also, this only shows the power of Silogue, not the underlying Prologue* \
*Oh, and go to ``http://localhost:8080/arch_rice.png`` to see static file serving*

```nim
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
      let newUser = User(name: "SmortBebe", age: 1)
      # % returns a JSONNode,
      # respjson responds with JSON to the client      
      respjson %newUser
      # respjson responds with JSON to the client
    post "time:string" json"user":
      var res = "You really shouldn't use JSON without a schema!\n"
      res &= "Your name is "
      if user.hasKey("name"):
        res &= user["name"].getStr() & "!\n"
        res &= "Don't give out your name to random websites!!"
      else:
        res &= "anonymous.\n"
        res &= "Being anonymous is a good thing to do on the web"
      resptext res
      # Respond with plaintext instead of HTML
  "/json-with-schema/{times:int}":
    # Use {} for path parameters
    post json"user:User":
      # POST data in JSON with "User" Schema
      var res = ""
      for i in 1..times:
        res &= user.name & " is " & $user.age & " years old!\n"
      resptext res
```

## Documentatoin
When finished, actual documentation shall be added.\
As of now, take a look in ``tests/``

## Configuration
Configure your `.env` file.

## Bugs
If `virtualPath` is set to `/`, nothing works; nothing's served.\
However, if `virtualPath` is set to anything else,\
Prologue serves on `/` and the specified directory.\
Remember: **It's not a bug; it's a feature!**
