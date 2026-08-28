class_name Coord
## Coord — the single world ↔ screen mapping utility for this project.
##
## Why canvas transform and not final transform?
##   Camera2D lives in the *canvas* transform: `vp.get_canvas_transform()` maps
##   world coords → viewport logical coords, and it changes every frame the
##   camera moves. `vp.get_final_transform()` is only the viewport → embedder
##   (window pixel) transform — stretch only, **no camera**.
##
## Legacy code that mapped world → screen through `get_final_transform()`
## only happened to be correct because the camera was static at scale 1
## (view offset zero), so final numerically equalled canvas. The moment the
## camera moves, final-transform mapping stops following the world. Every
## consumer (health-bar follow, the camera follower's published
## `active_unit_screen_y`, click mapping) must therefore go through canvas.
##
## Both helpers are pure static and take the live viewport as a parameter:
## no cached viewport, no cached transform — callers must pass
## `get_viewport()` fresh each call since the canvas transform changes per
## frame when the camera moves.

## World -> viewport logical screen coords (camera-aware).
static func world_to_screen(world: Vector2, vp: Viewport) -> Vector2:
	return vp.get_canvas_transform() * world


## Viewport logical screen coords -> world coords (camera-aware).
static func screen_to_world(screen: Vector2, vp: Viewport) -> Vector2:
	return vp.get_canvas_transform().affine_inverse() * screen