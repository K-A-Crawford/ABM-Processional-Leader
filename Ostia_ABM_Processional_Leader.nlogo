extensions [ GIS ]

globals [
  cityscape      ;; parameter used to denote the extended cityscape
  streets        ;; parameter used to denote streets
  commercial     ;; parameter used to denote buildings defined as having a commercial function
  production     ;; parameter used to denote buildings defined as having a production function
  domestic       ;; parameter used to denote buildings defined as have a residential function
  religious      ;; parameter used to denote buildings defined as having a religious function
  public         ;; parameter used to denote buildings defined as having a public function
  influence-field  ;; to control the total influence of building classifications
  the-leader     ;; parameter that designates one turtle within a procession as the leader.
  bldg-designation ;; parameter that denotes if a patch is defined as any type of building
  bldg-list      ;; used for determining which patches belong to a list of buildings
  open           ;; parameter used in a list to denote all available patches for moving towards
  closed         ;; parameter used in a list to denote all patches that were previously in an open list but were travelled across and therefore moved to a closed list
  optimal-path   ;; parameter used to determine the best path
    ]

patches-own   [
              street?             ;; true if patch is part of a street
              comm                ;; patches defined as commercial
              prod                ;; patches defined as production
              dom                 ;; patches defined as domestic
              rel                 ;; patches defined as religious
              pub                 ;; patches defined as public
              scape               ;; patches defined as belonging to the extended cityscape
              influence           ;; influence value of each patch
              visited?            ;; leaders, designate if a patch has been previously visited
             ; visit?              ;; processionals value for moving towards leaders path
              route?              ;; the route defined for return path to temple
              meaning
              ptype               ;; parameter that differentiates between building and street patches
              parent-patch        ;; pathfinding variable. Patch’s predecessor
              f                   ;; pathfinding variable. Value of knowledge plus heuristic cost function f()
              g                   ;; pathfinding variable. Value of knowledge cost function g()
              h                   ;; pathfinding variable. Value of heuristic cost function h()
              path?               ;; parameter used to identify the pathway for returning to the temple
              ]

breed [ leaders leader ]            ;; the agent in the model that is associated with a specified temple. They determine the route that the other processional participants should follow

breed [ observers observer ]        ;; the agents in the model that are Ostia city-dwellers. They are interested in watching the procession, but they will not follow or intentionally move towards the procession. They are positioned randomly along Ostia’s streets and can only move along streets

breed [ urbanites urbanite ]        ;; the agents in the model that populate the city but do not intentionally interact with the procession. They are randomly dispersed along Ostia’s street network and can only move along streets

observers-own
    [ ticks-since-here              ;; reporter, parameter that identifies how long an observer has stayed in one place watching a procession
      count-down]                   ;; reporter, parameter that tracks the number of ticks left before an observer can begin moving

leaders-own
    [
     traveled?        ;; parameter to keep track of if a walker has traveled to a target yet or not
     target           ;; parameter that determines which patch the leader is moving towards
     visited-list     ;; parameter that tracks which patches a leader has already travelled across so that they do not return to patches previously crossed
     home-xy          ;; parameter that sets the leaders start patch as the return destination
     path             ;; parameter used for determining best route back to the temple
     current-path     ;; parameter that designates what path is left to be followed
     ]



;;;;;;;;; setup ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all
  create-environment          ;; this creates the model environemnt
  setup-edges                 ;; this creates a boarder around every building that connects to the street. These are the patches that can be called as a target by leaders
end

to reset-parameters           ;; this sets/resets the building influence values along the border patches (setup-edges) of all the buildings
  reset-variables             ;; resets previous influence values
  cd                          ;; clears drawing of processional route
  ask patches [               ;; sets all patches that agents have walked across back to 0
    set visited? 0            ;; initialize the model by ensuring that none of the patches have been visited
    set path? 0]              ;; initialize the model by resetting all previous paths to 0
end

to display-agents             ;; separate setup procedure allows mutiple runs with different number of agents without resetting the environment
  ct                          ;; clears turtels from previous runs
  cd                          ;; clears drawing
  reset-ticks                 ;; set ticks back to 0
  setup-observers
  setup-urbanites
  setup-processionals
end

;;;;;;;;; to go  ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  process
  move-urbanites
  move-observers
  tick
end


;;;;;;;;; setup procedures ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to create-environment
  ask patches [set pcolor white]    ;;; sets background of model white

;;;;;;;;; load full cityscape dataset following GIS data;;;;;;;;;;

  ;; all of the relevant GIS shapefiles are loaded as well as the associated coordinate system
  gis:load-coordinate-system "Ostia_cityscape.prj"
   set commercial gis:load-dataset "extCommercial.shp"
  ;set commercial gis:load-dataset "commercial.shp"
  set production gis:load-dataset "production.shp"
  set domestic gis:load-dataset "Final_domestic.shp"
  set religious gis:load-dataset "religious.shp"
  set public gis:load-dataset "public.shp"
  set cityscape gis:load-dataset "Ostia_cityscape.shp"
  set streets gis:load-dataset "Second_century_streets_NL.shp"

  setup-world-envelope

;;;;;;;;;; display cityscape and building classifications as patches and set influence values as determined by sliders ;;;;;;;;;;;;
  ask patches
 [ ifelse gis:intersects? cityscape self [
      set scape true
    ]
  [
      set scape false
    ]
  ]
  ask patches with [ scape ]
  [ set pcolor grey + 4
    set ptype "building"]

 ask patches
   [ ifelse gis:intersects? commercial self [
      set comm true
    ]
  [
      set comm false
    ]
  ]
  ask patches with [ comm ]
  [ set pcolor green + 2
    set ptype "building"]

  ask patches
 [ ifelse gis:intersects? production self [
      set prod true
    ]
  [
      set prod false
    ]
  ]
  ask patches with [ prod ]
  [ set pcolor orange
    set ptype "building"]

   ask patches
 [ ifelse gis:intersects? domestic self [
      set dom true
    ]
  [
      set dom false
    ]
  ]
  ask patches with [ dom ]
  [ set pcolor yellow
    set ptype "building"]

    ask patches
 [ ifelse gis:intersects? religious self [
      set rel true
    ]
  [
      set rel false
    ]
  ]
  ask patches with [ rel ]
  [ set pcolor pink
    set ptype "building"]

    ask patches
 [ ifelse gis:intersects? public self [
      set pub true
    ]
  [
      set pub false
    ]
  ]
  ask patches with [ pub ]
  [ set pcolor blue
    set ptype "building"]

 ask patches
  [ ifelse gis:intersects? streets self [
    set street? true
    ]
    [
      set street? false
    ]
  ]
  ask patches with [ street? ]
  [ set pcolor black
    set ptype "street"]
end

;;;;;;;;;;; create border patches between buildings and streets;;;;;;;

;; if the relevant patch is part of a building patch group and next to street patches, then it will be changed to an edge patch
;; if the building influence values specified on the interface are specific to these edge patches.
;;This ensures that the influence value can be registered by the leader without requiring the agent to enter the different buildings

to setup-edges
  ask patches with [pcolor = green + 2]
    [if any? neighbors with [pcolor = black]
      [set pcolor green - 2
       set ptype "street"]
    ]
  ask patches with [pcolor = orange]
    [if any? neighbors4 with [pcolor = black]
      [set pcolor orange - 2
       set ptype "street"]
    ]
  ask patches with [pcolor = yellow]
    [if any? neighbors4 with [pcolor = black]
      [set pcolor yellow - 2
       set ptype "street"]
    ]
  ask patches with [pcolor = blue]
    [if any? neighbors4 with [pcolor = black]
      [set pcolor blue - 2
       set ptype "street"]
    ]
  ask patches with [pcolor = pink]
    [if any? neighbors4 with [pcolor = black]
      [set pcolor pink - 2
       set ptype "street"]
    ]
  ask patches with [pcolor = 38]
    [if any? neighbors4 with [pcolor = black]
      [set pcolor 38 - 2
        ]
    ]
  ask patches with [pcolor = 84]
    [if any? neighbors4 with [pcolor = black]
      [set pcolor 84 - 2
        ]
    ]
 if extended-influence = true [
    ask patches with [pcolor = grey + 4]
      [if any? neighbors4 with [pcolor = black]
        [set pcolor grey
         set ptype "building"
        ]
       ]
    ]
end

to setup-world-envelope
  gis:set-world-envelope gis:envelope-of cityscape
 ;; defines the limits of the world parameters of the interface
  let world gis:world-envelope
  gis:set-world-envelope world
end

;;;;;;;;;;;next setup procedure;;;;;;;;;;;;;;;;;;;;;;;;;
to reset-variables                                 ;; resets the building influence values without re-loading the entire model environment
  ask patches [set path? 0]
  ask patches with [pcolor = black]
    [set influence 0]
  ask patches with [pcolor = green - 2]
    [set influence commercial-influence
     set ptype "street"]
  ask patches with [pcolor = orange - 2]
    [set influence production-influence
     set ptype "street"]
  ask patches with [pcolor = yellow - 2]
    [set influence domestic-influence
     set ptype "street"]
  ask patches with [pcolor = blue - 2]
    [set influence public-influence
     set ptype "street"]
  ask patches with [pcolor = pink - 2]
    [set influence religious-influence
     set ptype "street"]


  ;; if this is switched “on” in the interface, then influence values will be attributed to the extended cityscape buildings plots of land
  if extended-influence = true [
   ask patches with [pcolor = grey]
   [
   ifelse random-inf = true
;; if the switch is on/true, influence values are randomly attributed to ‘buildings’ located within the street network of the extended cityscape
;; this enables the agents to move within the extended cityscape rather than being predominately confined to the excavated city
            [set influence random 5
             set ptype "building"]
            [set influence ext-influence
             set ptype "building"]
   ]
  ]
  set bldg-list [9 57 25 45 135 105 36 82]
  set bldg-designation bldg-list          ;; patch list inclusive of specific pcolors

end


;;;;;;;;;;;urban agents setup ;;;;;;;;;;

to setup-observers
  create-observers num-observers [
    set size 3
    set color blue + 2
    set shape "person"
    set count-down ticks-to-observe          ;; this specifies how long an observer will stay in place and watch a procession. Specificed by slider in the interface
     ]
 ask observers [
    move-to one-of patches with [street?]    ;; moves all observers to a different random patch that is part of a street
      ]
end

to setup-urbanites
  create-urbanites num-urbanites [
    set size 3
    set color yellow
    set shape "person"
  ]
  ask urbanites [
    move-to one-of patches with [street?]]   ;; moves all urbanites to a different random patch that is part of a street

end

to setup-processionals
if Serapeum = true [      ;; setup procession specific to the Serapeum
    ;; initialize all parameters. This makes sure the model knows that none of the agents have moved and that all parameters are set to 0
    create-leaders 1
   [
    setxy -296 -17          ;; coordinates for placement of processionals agents in front of the Serapeum on the street
    set home-xy patch-here  ;; parameter that set the start patch as the same patch that will be returned to
    ask patch -296 -17 [set ptype "destination"]
    set visited-list []     ;; creates a list of patches that are visited by the leader, this sets the number of patches as 0
    set size 3
    set color red
    set shape "person"
    set the-leader self
    set heading 90
    set traveled? false
    if draw-route = true   ;; if true, a route will be traced following the leader
      [ pen-down ]
    ]
    ask leaders [
      define-target ]
  ]

 if Cybele = true [  ;; setup procession specific to the Campo della Magna Mater
    ;; initialize all parameters. This makes sure the model knows that none of the agents have moved and that all parameters are set to 0
    create-leaders 1
   [
    setxy 92 -72            ;; coordinate placement of the processional leader
    set home-xy patch-here  ;; parameter that set the start patch as the same patch that will be returned to
    ask patch 92 -72 [set ptype "destination"]
    set visited-list []     ;; creates a list of patches that are visited by the leader, this sets the number of patches as 0
    set size 3
    set color red
    set shape "person"
    set the-leader self
    set heading 90
    set traveled? false
    if draw-route = true    ;; if true, a route will be traced following the leader
      [ pen-down ]
    ]
  ask leaders [
    define-target ]
  ]

 if Forum = true [  ;; setup procession specific to the Forum temples
    ;; initialize all parameters. This makes sure the model knows that none of the agents have moved and that all parameters are set to 0
  create-leaders 1
   [
    setxy -52 26            ;; coordinate placement of the processional leader
    set home-xy patch-here  ;; parameter that set the start patch as the same patch that will be returned to
      ask patch -52 26 [set ptype "destination"]
    set visited-list []     ;; creates a list of patches that are visited by the leader, this sets the number of patches as 0
    set size 3
    set color red
    set shape "person"
    set the-leader self
    set heading 90
    set traveled? false
    if draw-route = true    ;; if true, a route will be traced following the leader
      [ pen-down ]
    ]
  ask leaders [
    define-target ]
  ]
end


;;;;;;; target procedures ;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to define-target                       ;; this defines the initial destination of leaders
  if ticks < procession-ticks
    [set target highest-influence]     ;; reporter that calculates the patch with the highest influence value in relation to the agent’s current position
  if ticks = procession-ticks          ;; once ticks reach pre-defined value, the procession will call the return home calculation
       [find-path-to-temple            ;; the procession will find the best route back to the start temple
       output-show (word "Shortest path length:" length optimal-path)]  ;; records in the output window the number of patches needed to reach the temple
  if ticks > procession-ticks
    [set target return-influence]      ;; reporter that calculates the highest-influence values following the best path back to the temple
end


;;;;;;;;;;;run-time procedure;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to process
  move-leaders
end


;;;;;;;;;leader procedures;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to move-leaders
  ask leaders [
    if target != nobody [
      if distance target = 0
        [
        define-target
        ]
      if distance target > 1
        [
        travel-leaders
        ]
       if distance target <= 1  ;; agent moves to the highest influence patch. This patch is then placed within the visited list so the agent cannot visit it again during this run of the simulation
        [
        move-to target
        set visited-list lput target visited-list
         ]
      ]
   ]

end

to travel-leaders
  ask leaders [
    move-towards-target
   ]
end

to move-towards-target
 ask leaders [
  ifelse [meaning] of patch-ahead 1 = "street"   ;; if the patch ahead of the agent’s current position is a street, either avoid that patch or continue moving forwards. This ensures that the agent follows the building influence values, and stays confined to the following a patch along the edge of buildings
     [ Avoid-Function ]
     [ Move-Function ]
  ]
end


;;;;;;

to Move-Function
 let t target
 ask leaders [
   if target != nobody [
      if any? all-possible-moves
          [face min-one-of all-possible-moves [distance t]    ;; takes into account all the possible ways of reaching the target patch and choses the best next patch to face towards
           fd 1
           ask patch-here [set visited? 1]
          ]
        ]
   ]
end

to Avoid-Function
  let t target
 ask leaders [
    if target != nobody [
      if any? all-possible-moves
      [face min-one-of all-possible-moves [distance t]  ;;;; takes into account all the possible ways of reaching the target patch and choses the best next patch to move towards
      ]
    ]
  ]
end

to leave-a-trail
  ask patch-here [set visited? 1]   ;; if values are greater than 0, than the associated reporter will discount this patch from calculations to determine the next highest influence value and therefore possible target locations
end

to determine-destination
  ask leaders [
   define-target]
end


;;;;;;;;;;;;return to temple;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;A* path finding algorithm;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to find-path-to-temple
  ask leaders [
    define-origin
    compute-route
  ]
end

to define-origin          ;; defines the current patch the leader is standing on at the max-ticks
  ask location-leader
    [set ptype "source"]  ;; this patch is defined as a source patch
end

to compute-route
  ask one-of leaders
   [
    set path find-a-path one-of patches with [ptype = "source"] one-of patches with [ptype = "destination"]
    set optimal-path path
    set current-path path
    ]
end

to-report location-leader
  report [patch-here] of the-leader
end

to-report find-a-path [ source-patch destination-patch]

  ; initialize all variables to default values
  let search-done? false
  let search-path []
  let current-patch 0
  set open []
  set closed []

  ; add source patch in the open list
  set open lput source-patch open

  ; loop until we reach the destination or the open list becomes empty
  while [ search-done? != true]
  [
    ifelse length open != 0
    [
      ; sort the patches in open list in increasing order of their f() values
       set open sort-by [ [?1 ?2] -> [f] of ?1 < [f] of ?2 ] open

      ; take the first patch in the open list
      ; as the current patch (which is currently being explored (n))
      ; and remove it from the open list
      set current-patch item 0 open
      set open remove-item 0 open

      ; add the current patch to the closed list
      set closed lput current-patch closed

      ; explore the Von Neumann (left, right, top and bottom) neighbors of the current patch
      ask current-patch
      [
        ; if any of the neighbors is the destination stop the search process
        ifelse any? neighbors4 with [(pxcor = [ pxcor ] of destination-patch) and (pycor = [pycor] of destination-patch)]
        [
          set search-done? true
        ]
        [
          ; the neighbors should not be obstacles or already explored patches (part of the closed list)
          ask neighbors4 with [ ptype != "building" and (not member? self closed) and (self != parent-patch) ]
          [
            ; the neighbors to be explored should also not be the source or
            ; destination patches or already a part of the open list (unexplored patches list)
            if not member? self open and self != source-patch and self != destination-patch
            [

              ; add the eligible patch to the open list
              set open lput self open

              ; update the path finding variables of the eligible patch
              set parent-patch current-patch
              set g [g] of parent-patch  + 1
              set h distance destination-patch
              set f (g + h)
            ]
          ]
        ]
      ]
    ]
    [
      ;; if a path is found (search completed) add the current patch (node adjacent to the destination) to the search path.
      user-message( "A path from the source to the destination does not exist." )
      report []
    ]
  ]

  ; if a path is found (search completed) add the current patch
  ; (node adjacent to the destination) to the search path.
  set search-path lput current-patch search-path

  ; trace the search path from the current patch
  ; all the way to the source patch using the parent patch
  ; variable which was set during the search for every patch that was explored
  let temp first search-path
  while [ temp != source-patch ]
  [
     ask temp
    [
      set influence 50   ;; this high influence value ensures that on calculating the route home, these patches are the most desirable to move towards
                         ;; this prevents the agent from travelling towards high influence buildings instead of staying on the street to go back to the temple
      set visited? 0
    ;  set route? true

;;      set pcolor 85                  ;; if eneabled this will display the possible route
    ]
    set search-path lput [parent-patch] of temp search-path
    set temp [parent-patch] of temp
  ]

  ; add the destination patch to the front of the search path
  set search-path fput destination-patch search-path

  ; reverse the search path so that it starts from a patch adjacent to the
  ; source patch and ends at the destination patch
  set search-path reverse search-path
;;  output-show (word "Shortest path length : " length optimal-path)

  ; report the search path
  report search-path
 ; output-show (word "Shortest path length : " length optimal-path)
 ;; procedure for enable return movement along defined route
end


;;;;;; building influence reporter calculations ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report highest-influence   ;; ensures that the most desirable patch to visit next has the highest influence value in relation to the agent’s current position
  let to-visit patches with [
     influence > 0 and
     not member? self [visited-list] of myself ]
  report max-one-of to-visit [ influence / ( distance myself ) ]
end

to-report return-influence
   let to-visit patches with [
     influence = 50 and           ;; only patches with a value of 50 will be considered in order to follow the route returning to the temple start point
     not member? self [visited-list] of myself ]
  report max-one-of to-visit [ influence / ( distance myself ) ]
end

to-report all-possible-moves
   report neighbors with [pcolor = black and visited? = 0 and distance myself  <= 1 or distance myself  > 0 ]
 end

;;;;;;;;;;;;;;;; to run urban agents procedures ;;;;;;;;;;;;;;;;;;;;;

to move-urbanites
  ask urbanites [    ;; if the next patch is not a street or there is another agent on that patch than the agent rotates 90 degrees in a random direction. If the patch is free than the agent can travel forward one patch
    ifelse [ptype] of patch-ahead 1 != "street" and not any? other turtles-on patch-ahead 1
      [rt random 90]
      [fd 1]
   ]
end

to move-observers
  ask observers [
   ifelse any? leaders in-radius viewing-radius   ;; if there are any processional agents within the viewing distance defined in the interface, than wait a certain number of ticks
    [
      stay
    ]
    [
      ifelse [ptype] of patch-ahead 1 != "street" and not any? other turtles-on patch-ahead 1  ;; if there is no procession, the patch ahead is a street and there is not another agent in the way, then the observer can move forward
      [rt random 90]
      [fd 1]
    ]
  ]
end

to stay
  set count-down count-down - 1   ;; determines the length of time an observer will stay in one position. This value is then subtracted by one each tick. Once 0 is reached, the agent can move
  if count-down = 0
    [move-observers
     reset-count-down]
end

to reset-count-down
  set count-down ticks-to-observe
end
@#$#@#$#@
GRAPHICS-WINDOW
369
13
1097
502
-1
-1
0.6
1
10
1
1
1
0
1
1
1
-600
600
-400
400
1
1
1
ticks
30.0

BUTTON
44
84
110
117
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
159
33
347
66
commercial-influence
commercial-influence
0
5
5.0
1
1
NIL
HORIZONTAL

SLIDER
159
69
347
102
production-influence
production-influence
0
5
1.0
1
1
NIL
HORIZONTAL

SLIDER
158
141
346
174
religious-influence
religious-influence
0
5
1.0
1
1
NIL
HORIZONTAL

SLIDER
158
177
345
210
public-influence
public-influence
0
5
1.0
1
1
NIL
HORIZONTAL

SLIDER
158
105
346
138
domestic-influence
domestic-influence
0
5
1.0
1
1
NIL
HORIZONTAL

TEXTBOX
189
10
339
28
Ostia Building Parameters
11
0.0
1

SLIDER
1160
113
1343
146
num-observers
num-observers
0
300
200.0
1
1
NIL
HORIZONTAL

SLIDER
1164
58
1346
91
num-urbanites
num-urbanites
0
300
300.0
1
1
NIL
HORIZONTAL

BUTTON
201
412
326
445
NIL
Display-agents
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
202
456
257
489
NIL
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
265
457
320
490
Go
Go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
16
415
164
448
procession-ticks
procession-ticks
0
2000
1000.0
10
1
NIL
HORIZONTAL

SWITCH
122
351
228
384
Serapeum
Serapeum
0
1
-1000

SWITCH
9
351
112
384
Cybele
Cybele
1
1
-1000

SWITCH
234
351
337
384
Forum
Forum
1
1
-1000

SWITCH
17
454
164
487
draw-route
draw-route
1
1
-1000

TEXTBOX
1215
38
1312
56
Agent Parameters
11
0.0
1

SWITCH
92
242
278
275
extended-influence
extended-influence
1
1
-1000

SWITCH
72
279
190
312
random-inf
random-inf
1
1
-1000

SLIDER
192
279
302
312
ext-influence
ext-influence
0
5
0.0
1
1
NIL
HORIZONTAL

BUTTON
5
132
145
165
NIL
reset-parameters
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
103
222
280
250
Extended Cityscape Parameters
11
0.0
1

OUTPUT
1127
341
1395
395
12

TEXTBOX
1179
321
1388
349
reports length of return route
11
0.0
1

SLIDER
1160
146
1343
179
ticks-to-observe
ticks-to-observe
0
30
10.0
.5
1
ticks
HORIZONTAL

SLIDER
1160
179
1343
212
viewing-radius
viewing-radius
0
30
10.0
1
1
patches
HORIZONTAL

MONITOR
1209
407
1330
452
leader patch
location-leader
17
1
11

SLIDER
1162
231
1341
264
step-size
step-size
0
3
0.75
.25
1
NIL
HORIZONTAL

TEXTBOX
146
323
296
341
Procession 
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

This model simulates a processional route from one of three different locations at Ostia. Movememnt of the processional leader is informed by passing buildings with different influence values. The processional leader determines a route following the highest influence values for a defined number of ticks, at which point the shortest route along the city's street network is then determiend to return to the start position. There are also two sets of urban agents, urbanites and observers. Urbanites move randomly along the street network and avoid running into other agents. The observers will stop moving and watch a passing procession that is within a certain radius and for a specified duration of time. Othrwise their movemement also travels randomly along the city's streets, avoiding other agents  

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

Press the setup button, this loads the GIS datasets

Press the reset-paramaters button, this associates the influence values with specific buildings

Press the display-agents button to load agents within the model

Press Go to run the model. 

The various paramaters (building influence value, duration of the procession, number of agents) can all be adjusted using the slider and switches on the interface

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

- Traffic Grid model – Netlogo Library


- Lukas, Jiri (2014) Town - Traffic and Crowd simulation.
http://ccl.northwestern.edu/netlogo/models/community/Town%20-%20Traffic%20&%20Crowd%20simulation 


- Singh, Meghendra (2014) Astardemo1: A* pathfinding algorithm http://ccl.northwestern.edu/netlogo/models/community/Astardemo1



	
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
