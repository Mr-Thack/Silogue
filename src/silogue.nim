import prologue
export prologue
import macros
import std/strtabs
import prologue/middlewares/staticfile
import prologue/middlewares/staticfilevirtualpath
import strutils
export strutils
import std/options
export options
import std/json
export json

# I tried a template, buy I couldn't get that working
macro strToIdent(s: NimNode): untyped =
  # Take a string literal, make an ident node
  result = quote do:
    newIdentNode `s`.repr.strip(chars={'"'})

let env = loadPrologueEnv(".env")
var app: Prologue

proc genApp*(): Prologue =
  app = newApp()
  let staticDir = env.get("staticDir")
  # Will be "" if not set
  let virtualPath = env.get("virtualPath")  
  # Then, user can set public display directory
  if staticDir != "":  # TODO: Move this into its own function
    if virtualPath != "":
      echo "Serving " & staticDir & " to " & virtualPath
      app.use(staticFileVirtualPathMiddleware(staticDir, virtualPath))
    else:  # User wants internal dir to be same as external
      echo "Serving " & staticDir
      app.use(staticFileMiddleware(staticDir))
  return app

template resptext*(p: untyped): untyped =
  resp plainTextResponse(p)

template respjson*(p: untyped): untyped =
  resp jsonResponse(p)

proc runApp*() =
  app.run() 

template genBoilerplate*(funcbody: untyped): untyped =
  (proc (ctx: Context) {.async.} = 
    let ctx {.inject.} = ctx
    funcbody)

template paramError(pname: string): untyped =
  await ctx.respond(Http400, "Invalid Format for Parameter " & pname)

# This is for something than directly needs the string from ctx.getParams
template validate*(valtype: typedesc, body: untyped): untyped =
 func validateParam*(t: typedesc[valtype], rawval: string): Option[valtype] =
    let rawval {.inject.} = rawval
    body

# This is for a type built on top of an existing type
template validateFrom*(valtype: typedesc, reqtype: typedesc, body: untyped): untyped =
  func validateParam*(t: typedesc[valtype], rawval: string): Option[valtype] =
    let rawval {.inject.} = validateParam(reqtype, rawval)
    body

# Prologue has getQueryParamsOption, and for the other HTTP Verbs too,
# But I didn't know about that when making this
# Plus it's not that much extra overhead
validate(string):
  if rawval.len != 0:
    some rawval
  else:
    none string

validateFrom(int, string):
  if rawval.isSome:
    try:
      return some(rawval.get().parseInt)
    except:
      return none int
  none int

macro parseQueryParam*(p, k, isOptional: untyped): untyped =
  let ptype = strToIdent k
  let pident = strToIdent p
  result = nnkStmtList.newTree()
  if not isOptional.boolVal:
    # This is the identity Node of the tmp holder
    # It's named oddly so that so that the user doesn't accidentally use it
    let tmp = ident("TMP" & pident.repr & "TMP")
    let tmpbod = quote do:
      let `tmp` = validateParam(typedesc[`ptype`], ctx.getQueryParams(`p`))
      if `tmp`.isNone:
        paramError(`p`)
      var `pident` = `tmp`.get()
    result.add tmpbod
  else:
    let tmpbod = quote do:
      var `pident` = validateParam(typedesc[`ptype`], ctx.getQueryParams(`p`))
    result.add tmpbod

# These 2 functions are almost the same
# It would be beneficial to merge them somehow
macro parsePathParam*(p, k, isOptional: untyped): untyped =
  let ptype = strToIdent k
  let pident = strToIdent p
  result = nnkStmtList.newTree()
  if not isOptional.boolVal:
    let tmp = ident("TMP" & pident.repr & "TMP")
    let tmpbod = quote do:
      let `tmp` = validateParam(typedesc[`ptype`], ctx.getPathParams(`p`))
      if `tmp`.isNone:
        paramError(`p`)
      var `pident` = `tmp`.get()
    result.add tmpbod
  else:
    let tmpbod = quote do:
      var `pident` = validateParam(typedesc[`ptype`], ctx.getPathParams(`p`))
    result.add tmpbod

macro parseBodyParam*(p, k, isOptional, format: untyped): untyped =
  let ptype = strToIdent k
  let pident = strToIdent p
  result = nnkStmtList.newTree()
  if format.strVal == "form": # I should clean this, but it works and I don't feel like it
    if not isOptional.boolVal:
      let tmp = ident("TMP" & pident.repr & "TMP")
      let tmpbod = quote do:
        let `tmp` = validateParam(typedesc[`ptype`], ctx.getPostParams(`p`))
        if `tmp`.isNone:
          paramError(`p`)
        var `pident` = `tmp`.get()
      result.add tmpbod
    else:
      let tmpbod = quote do:
        var `pident` = validateParam(typedesc[`ptype`], ctx.getPostParams(`p`))
      result.add tmpbod
  elif format.strVal == "json":
    if k.strVal == "NOSCHEMA":
      let tmpbod = quote do:
        var `pident` = parseJson(ctx.request.body())
      result.add tmpbod
    else: 
      let tmpbod = quote do:
        var `pident` = to(parseJson(ctx.request.body()), `ptype`)
      result.add tmpbod

macro parseQueryParams*(p: untyped): untyped =
  let params = p.repr
  if params == "" or params == "()":
    # Nim is being weird and it gives me one or the other
    return
  result = nnkStmtList.newTree()
  for s in params.strip(chars={'"'}).split("&"):
    let kv = s.split(":")
    if kv.len != 2:
      echo "Here ", p.repr
      echo "[ERROR::Silogue] Check your syntax [in param parser]"
      quit 1
    let param = kv[0]
    let ptype = kv[1].replace("?")  # Gets rid of all question marks
    let isOptional = kv[1].contains("?")
    let part = quote do:
      parseQueryParam(`param`, `ptype`, `isOptional`)
    result.add part


# Stupid Nim won't let me return a tuple
macro parsePathParams*(p: untyped): untyped =
  let params = p.repr
  result = nnkStmtList.newTree()
  if params == "/":
    return result
  for s in params.strip(chars={'"'}).split("/"):
    let news = s.strip(chars={'{', '}'})
    if s != news:
      # Will be false if name == name
      # But not when name == {name:string}
      let kv = news.split(":")
      # This code feels redundant,
      # But I'll need to learn more Nim first
      # to make it better
      if kv.len != 2:
        echo "HeRe ", p.repr
        echo "Some sort of syntax error probably"
        quit 1
      let param = kv[0]
      let ptype = kv[1].replace("?")
      let isOptional = kv[1].contains("?")
      let part = quote do:
        parsePathParam(`param`, `ptype`, `isOptional`)
      result.add part
  return result

macro parseBodyParams*(p: untyped): untyped =
  if p.repr == "()" or p.repr == "":
    return
  let format = p[0].strVal.strip(chars={'"'})
  let params = p[1].strVal
  result = nnkStmtList.newTree()
  for s in params.split('&'):
    let kv = s.split(":")
    if kv.len == 1:
      let param = kv[0]
      let isOptional = param.contains("?")
      let part = quote do:
        parseBodyParam(`param`, "NOSCHEMA", `isOptional`, `format`)
      result.add part
    elif kv.len != 2:
      echo "Somethign wrong: ", p.repr
      echo "Silogue Error, Check you Syntax, probably"
      quit 1
    else:
      let param = kv[0]
      let ptype = kv[1].replace("?")
      let isOptional = kv[1].contains("?")
      let part = quote do:
        parseBodyParam(`param`, `ptype`, `isOptional`, `format`)
      result.add part

# I would've merged this in the parsePathParams macro,
# But stupid Nim won't let me return a tuple
# if one of the elements is a NimNode
# TODO: FIX IT
func fixPath(macpath: string): string =
  result = "/"
  for s in macpath.split("/"):
    if s.len != 0:
      if not s.contains("{"):
        result &= s
      else:
        result &= s[0 ..< s.find(':')] & "}"
      result &= '/'

macro proxySetup*(verb, path, params, bodyParams, handler: untyped): untyped =
  var corebod = nnkStmtList.newTree()
  
  let pathBod = quote do:
    parsePathParams(`path`)
  let newpath = fixPath(path.repr.strip(chars={'"'}))  # Don't know why I'm doing this
  corebod.add pathBod
  
  let paramCheckBod = quote do:
    parseQueryParams(`params`)
  corebod.add paramCheckBod # We add the handler after we add the checker functions

  let bodyCheckBod = quote do:
    parseBodyParams(`bodyParams`)
  corebod.add bodyCheckBod
  
  # Lastly, we wrap it around with the boilerplate function declaration
  corebod.add handler
  
  let fbod = newCall("genBoilerplate", corebod)
  result = quote do:
    app.`verb`(`newpath`, `fbod`)

macro routes*(rs: varargs[untyped]): untyped =
  result = nnkStmtList.newTree()
  # echo rs[0].treeRepr  # comes wrapped in args type
  # echo "\n"
  for point in rs[0]:
    #"/":
    #  get "":
    #    resp hello
    # 
    let route = point[0]  # The path in the system
    for node in point[1]:
      let verb = node[0]
      var handler: NimNode
      var params = NimNode()
      var bodyParams = NimNode()
      if node[1].kind == nnkStrLit:
        # get "query:params"
        params = node[1]
        handler = node[2]
      elif node[1].kind == nnkCommand:        
        # post "query:Params" fmt"Body:Params" 
        params = node[1][0]
        bodyParams = node[1][1]
        handler = node[2]
      elif node[1].kind == nnkStmtList:
        # get: # No Query Params
        handler = node[1]
      elif node[1].kind == nnkCallStrLit:
        # post with"body:params"
        bodyParams = node[1]
        handler = node[2]
      else:
        # Maybe this should be static
        echo rs.repr
        echo rs.treeRepr
        # TODO: Make this use Prologue logger
        echo "[ERROR::Silogue] Check your Syntax"
        quit 1
      result.add newCall(ident "proxySetup", verb, route, params, bodyParams, handler)
  result.add newCall("runApp")  # lastly, run app