# Warehouse structure kit

Built by `warehouse/structure.py` (`_kit/run.sh warehouse/structure.py <name>` from `art/`). Each item folder has the FBX, its 1024 texture, `preview.png` and `solo.png`.

## Grid and origins

- 1 stud is about 0.3 m. Building grid is 16 studs. Floor tiles are 32.
- Every origin is the bottom centre of the piece's bounding box. Front faces -y.
- Walls are 16 wide, 16 tall, 1 deep (y -0.5 to 0.5). Put the origin on the wall line; every wall type shares it, so they swap in place.
- Rotate floor tiles and giant pillar segments in 90 degree steps so repeats don't line up. Mirroring floors is fine too.

## Pieces

| Piece | Footprint (x by y) | Height | Notes |
|---|---|---|---|
| wall_lower | 16 x 1 | 16 | concrete block knee wall to 5, corrugated steel above, girt at 10 |
| wall_upper | 16 x 1 | 16 | corrugated steel, girts at 2 and 10. Stack on any wall to any height |
| wall_lower_damaged | 16 x 1 | 16 | dented sheet, lower left corner torn and peeled in |
| wall_oily | 16 x 1 | 16 | black oil runs and smeared handprints on the block |
| wall_corner | 1.4 x 1.4 | 16 | trim post. Centre it on a wall end, inside corner or panel seam; stacks every 16 |
| column | 1.6 x 1.88 | 32 | steel I-beam with a bolted splice at its foot. Stack on column_base, then on itself |
| column_base | 3.2 x 3.2 | 32 | base plate, anchor bolts, hazard guard to 4.5, oil at the foot |
| giant_pillar | 24 x 24.08 | 32 | concrete, chipped corners, formwork lines, "D7" painted on front and back. Stacks every 32 |
| giant_pillar_base | 30 x 30 | 32 | 2-tall footing, hazard band, brown flood stain up to 22, oil. Shaft is 24 x 24 like the segment |
| roof_truss | 32 x 0.7 | 4 | spans 32 along x. Chain end to end; one row every 32 along y |
| roof_panel | 32 x 32 | 1.8 | seen from below. Purlins at x = -12, -4, 4, 12 run along y, insulation sags between, a few torn flaps. Top of deck is 1.8 above the origin |
| roof_skylight | 32 x 32 | 2.6 | same as roof_panel with an 8 x 16 skylight in the middle |
| dock_door | 16 x 2.2 | 16 | 12 x 12 opening. y -1.1 to 1.1 but still centred on the wall line (hood inside, bumpers outside) |
| floor_tile | 32 x 32 | 0.2 | dark stained concrete, saw-cut joints every 16 |
| floor_lane | 32 x 32 | 0.2 | yellow lane line along x at y = 0, worn hatch box |
| floor_cracked | 32 x 32 | 0.2 | crack network and a black oil stain |
| floor_wet | 32 x 32 | 0.22 | damp concrete plus a `Wet` patch part |
| floor_wood | 32 x 32 | 0.2 | pale showroom planks along x, scuffed |
| floor_carpet | 32 x 32 | 0.2 | dingy carpet tiles (8 square) with a squiggle print |
| floor_checker | 32 x 32 | 0.2 | old 2-stud cream and terracotta store tile, cracked, a few gone |
| curb | 32 x 1.2 | 1 | concrete curb in chipped yellow paint, chains end to end |
| ramp | 16 x 16 | 4.6 | concrete ramp rising from 0.15 at -y to 4 at +y, side walls with yellow-striped caps up to 4.6 |
| drop_ceiling | 16 x 16 | 1.41 | 2 x 4 tiles on a T-bar grid; bottom of the grid is the origin. Hang it with the origin at ceiling height |
| wall_tile | 16 x 1 | 16 | white square bathroom tile, grimy grout, teal trim course at 3.2 |
| wall_pastel | 16 x 1 | 16 | butter-yellow plaster, faded orange double stripe, baseboard |
| wall_sky | 16 x 1 | 16 | the face is a `Screen` part showing a painted sky |
| wall_windows | 16 x 1 | 16 | 4 x 4 small deep-set windows |
| shutter_front | 16 x 1 | 16 | mall storefront, 13 x 11 opening, sign band, roll-down grille |
| floor_checker_color | 32 x 32 | 0.2 | faded primary checker, 2-stud cells |
| floor_pool | 32 x 32 | 0.25 | aqua pool mosaic, dark lane along x, a shallow water layer in the middle (inside Body) |
| floor_grass | 32 x 32 | 0.3 | indoor fake turf, worn path along x |
| floor_marble | 32 x 32 | 0.2 | pink-beige and cream diamond checker marble with dark bands |
| floor_carpet_blue | 32 x 32 | 0.2 | faded periwinkle carpet |
| floor_carpet_wild | 32 x 32 | 0.2 | loud arcade carpet: neon squiggles and dots on near-black |
| wall_curved | 16 x 16 | 16 | quarter-round lime plaster wall, 1 thick. The convex face is a radius 16 arc around the back corner (8, 8) of its box, so its ends sit on the box edges x = -8 (open toward +y) and y = -8 (open toward +x) |
| floor_hatch | 32 x 32 | 6.58 | concrete floor tile with a 5 x 5 hatch over a 6-deep shaft and a steel ladder. The origin is the bottom of the shaft: put it 6 below the other floors so its floor top (6.2) lines up with theirs (0.2) |
| stair_flight | 8 x 16 | 11.39 | carpeted stairs, 16 steps of 0.5 up and 1 deep, rising toward +y to 8; wooden handrail on the +x side up to 11.4 |

## How they tile

- Floor tiles butt edge to edge on the 32 grid (floor_hatch included, 6 lower). Joints, seams and lane lines land on the edges or run straight through, and stains stay away from the edges, so any tile sits next to any other. Floor tops are at 0.2 (grass 0.3), so the floor level is 0.2.
- Walls tile side by side every 16 and stack every 16. Keep wall_lower and its variants on the bottom row, wall_upper above. Corrugation, girts and block courses line up across neighbours.
- Columns and giant pillars stack in 32 segments: base first, then plain segments. Turn each giant_pillar segment 90 degrees from the one below.
- Trusses every 32. roof_panel and roof_skylight fill the 32 squares between them; their purlins and insulation sag join across panels. Sit them on the trusses: panel origin at truss top.
- Curbs chain every 32. The ramp is 16 wide, so two fit a 32 tile.

## Parts that move or glow

- dock_door `Door`: the slatted door. Origin is the top of the opening (12 up). It sits inside the wall thickness, so it can slide up 4 into the header unseen; to open all the way, shrink its height toward the origin (it rolls up into the hood) or slide it 12 if the wall above is hidden.
- shutter_front `Door`: the grille, same idea. Origin at the top of the opening (11 up), hidden inside the header when raised.
- floor_hatch `Door`: the diamond-plate lid. Origin on the hinge along its back (+y) edge; rotate about x to swing it up.
- roof_skylight `Glow`: the dirty cracked glass, one pane broken out. Light it as cold moonlight.
- drop_ceiling `Glow`: the light panel. Flicker it or leave it dead.
- wall_windows `Glow`: all 16 panes in one part.
- floor_wet `Wet`: the puddle. Give it a glossy look (SmoothPlastic, some Reflectance) so it reads wet.
- wall_sky `Screen` and shutter_front `Screen`: flat faces with 0 to 1 UVs. Defaults are a painted sky and a blank faded sign; swap the image in game.
- The dock door's small red lamp above the opening is baked into Body.
