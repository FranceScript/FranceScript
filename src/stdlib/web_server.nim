# Standard Library - Web Server Module
# Provides a simple web server implementation with routing capabilities

import asynchttpserver, asyncdispatch, tables, json

type
  ServeurWeb* = ref object
    port: int

  Requete* = ref object
    methode*: string
    chemin*: string
    parametres*: Table[string, string]
    corps*: string
    entetes*: Table[string, string]

var globalRoutes {.threadvar.}: Table[string, proc(req: Requete): string {.closure, gcsafe.}]
var routesInitialized {.threadvar.}: bool

proc newServeurWeb*(): ServeurWeb =
  new(result)
  result.port = 3000
  if not routesInitialized:
    globalRoutes = initTable[string, proc(req: Requete): string {.closure, gcsafe.}]()
    routesInitialized = true

proc definirPort*(serveur: ServeurWeb, port: int) =
  serveur.port = port

proc get*(serveur: ServeurWeb, chemin: string, gestionnaire: proc(req: Requete): string {.closure, gcsafe.}) =
  if not routesInitialized:
    globalRoutes = initTable[string, proc(req: Requete): string {.closure, gcsafe.}]()
    routesInitialized = true
  globalRoutes["GET:" & chemin] = gestionnaire

proc post*(serveur: ServeurWeb, chemin: string, gestionnaire: proc(req: Requete): string {.closure, gcsafe.}) =
  if not routesInitialized:
    globalRoutes = initTable[string, proc(req: Requete): string {.closure, gcsafe.}]()
    routesInitialized = true
  globalRoutes["POST:" & chemin] = gestionnaire

proc put*(serveur: ServeurWeb, chemin: string, gestionnaire: proc(req: Requete): string {.closure, gcsafe.}) =
  if not routesInitialized:
    globalRoutes = initTable[string, proc(req: Requete): string {.closure, gcsafe.}]()
    routesInitialized = true
  globalRoutes["PUT:" & chemin] = gestionnaire

proc delete*(serveur: ServeurWeb, chemin: string, gestionnaire: proc(req: Requete): string {.closure, gcsafe.}) =
  if not routesInitialized:
    globalRoutes = initTable[string, proc(req: Requete): string {.closure, gcsafe.}]()
    routesInitialized = true
  globalRoutes["DELETE:" & chemin] = gestionnaire

proc handleRequest(req: Request): Future[void] {.async, gcsafe.} =
  let methode = $req.reqMethod
  var chemin = req.url.path
  
  if '?' in chemin:
    let parts = chemin.split('?')
    chemin = parts[0]
  
  let routeKey = methode & ":" & chemin
  
  var responseBody: string
  var contentType = "text/plain; charset=utf-8"  # Default to text
  
  if routesInitialized and globalRoutes.hasKey(routeKey):
    let gestionnaire = globalRoutes[routeKey]
    var requete = Requete(
      methode: methode,
      chemin: chemin,
      parametres: initTable[string, string](),
      corps: "",
      entetes: initTable[string, string]()
    )
    
    # Parse query parameters
    if req.url.query != "":
      let queryParams = req.url.query.split('&')
      for param in queryParams:
        let parts = param.split('=')
        if parts.len == 2:
          requete.parametres[parts[0]] = parts[1]
    
    # Parse headers
    for name, value in req.headers.pairs:
      requete.entetes[name] = value
    
    # Call the handler
    responseBody = gestionnaire(requete)
    
    # Detect if response is JSON
    if responseBody.startswith("{") or responseBody.startswith("["):
      contentType = "application/json; charset=utf-8"
  else:
    responseBody = "Route not found"
  
  let headers = newHttpHeaders([
    ("Content-Type", contentType),
    ("Access-Control-Allow-Origin", "*")
  ])
  
  await req.respond(Http200, responseBody, headers)

proc ecouter*(serveur: ServeurWeb) {.async.} =
  var server = newAsyncHttpServer()
  await server.serve(Port(serveur.port), handleRequest)

proc demarrer*(serveur: ServeurWeb) =
  try:
    waitFor serveur.ecouter()
  except Exception as e:
    echo e.msg

# Helper functions
proc reponseJson*(objet: auto): string =
  # FIX: utiliser % pour convertir en JsonNode puis $ pour convertir en string
  return $(objet)

proc reponseTexte*(texte: string): string =
  return texte

proc obtenirParametre*(req: Requete, nom: string): string =
  if req.parametres.hasKey(nom):
    return req.parametres[nom]
  return ""

proc obtenirEntete*(req: Requete, nom: string): string =
  if req.entetes.hasKey(nom):
    return req.entetes[nom]
  return ""