import prologue
import macros
import std/strtabs
import prologue/middlewares/staticfile
import prologue/middlewares/staticfilevirtualpath
export prologue
import strutils

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

proc runApp*() =
  app.run() 

proc onget*(path: string, body: proc) =
  app.get(`path`, `body`)

proc onpost*(path: string, body: proc) =
  app.post(`path`, `body`)

template genBoilerplate*(funcbody: untyped): untyped =
  (proc (ctx: Context) {.async.} = 
    let ctx {.inject.} = ctx
    funcbody)

proc parseParams(params: string): StringTableRef = 
  # I feel like there's a more effecient way than using a table
  result = newStringTable()
  # Also, the keys don't retain their order
  if params == "" or params == "()":
    # Nim is being weird and it gives me one or the other
    return result
  for s in params.strip(chars={'"'}).split("&"):
    let kv = s.split(":")
    result[kv[0]] = kv[1]
    # There's probably a cleaner way



#macro optionalGuard(isOptional: untyped) =  
  #if not boolVal(isOptional):
  #  let guard = quote do:
  #    if `pnameFixed` == "":
  #      await ctx.respond(Http400, "Invalid Format: " & `pname`)
  #  result.add(guard)

template paramError*(pname: string): untyped =
  await ctx.respond(Http400, "Invalid Format for Parameter " & pname)

macro ParseQueryString*(p, isOptional: untyped): untyped =
  # p is actually a strLiteral, but Nim's annoying me when I do that
  let pident = strToIdent p
  result = nnkStmtList.newTree()
  let core = quote do:
    var `pident` = ctx.getQueryParams(`p`)
  result.add core
  if not boolVal(isOptional):
    let check = quote do:
      if `pident`.len == 0:
        paramError(`p`)
    result.add check

macro ParseQueryInt*(p, isOptional: untyped): untyped =
  # actually: string, bool
  let pident = strToIdent p
  if not boolVal(isOptional):
    result = quote do:
      if ctx.getQueryParams(`p`).len == 0:
        paramError(`p`)
      var `pident` = parseInt(ctx.getQueryParams(`p`)) 
  else:
    result = quote do:
      var `pident`: Option[int]
      try:
        `pident` = some(ctx.getQueryParams(`p`))
      except:
        `pident` = none(int)
      if `pident`.isNone:
        paramError(`p`)
      

macro proxySetup*(verb, path, params, handler: untyped): untyped =
  let handleFunc = ident("on" & verb.repr)
  let parsedParams = parseParams(params.repr)
  var corebod = nnkStmtList.newTree()
  var requiredParams: seq[string] = @[]
  for k, v in parsedParams.pairs:
    let isOptional = v.contains("?")  # For optional
    # leading false 
    let handlerCode = newIdentNode("ParseQuery" & v)
    let part = quote do:
      `handlerCode`(`k`, `isOptional`)
    corebod.add part
  corebod.add handler # We add the handler after we add the checker functions
  # Lastly, we wrap it around with the boilerplate function declaration
  let fbod = newCall("genBoilerplate", corebod)
  return quote do:
    `handleFunc`(`path`, `fbod`)

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
      if node[1].kind == nnkStrLit:
        params = node[1]
        handler = node[2]
      elif node[1].kind == nnkStmtList:
        handler = node[1]
      else:
        # TODO: Make this use Prologue logger
        echo "Check your Syntax"
        quit 1
      result.add newCall(ident "proxySetup", verb, route, params, handler)
  result.add newCall("runApp")  # lastly, run app