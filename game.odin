package main

import "core:fmt"
import math "core:math"
import rand "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
MAX_ENTITIES :: 300000

GRID_CELL_SIZE :: 15
GRID_WIDTH :: (SCREEN_WIDTH / GRID_CELL_SIZE) + 1
GRID_HEIGHT :: (SCREEN_HEIGHT / GRID_CELL_SIZE) + 1

INITIAL_SPAWN_COOLDOWN :: 0.12
INITIAL_BULLET_COOLDOWN :: 0.075

EntityType :: enum {
	PLAYER,
	BULLET,
	ENEMY,
}

RenderInfo :: struct {
	type:          EntityType,
	color:         rl.Color,
	size:          f32,
	to_be_removed: bool,
}

Movement :: struct {
	direction: rl.Vector2,
	speed:     f32,
}


main :: proc() {
	dt: f32
	game_time: f32 = 0
	current_no_entities := 0
	enemy_spawn_cooldown: f32 = INITIAL_SPAWN_COOLDOWN
	bullet_timer: f32 = INITIAL_BULLET_COOLDOWN
	current_bullet_angle: i32 = 0

	movement_soa: #soa[dynamic]Movement
	movement_soa = make(#soa[dynamic]Movement, MAX_ENTITIES)
	defer delete(movement_soa)

	position_soa: #soa[dynamic]rl.Vector2
	position_soa = make(#soa[dynamic]rl.Vector2, MAX_ENTITIES)
	defer delete(position_soa)

	render_soa: #soa[dynamic]RenderInfo
	render_soa = make(#soa[dynamic]RenderInfo, MAX_ENTITIES)
	defer delete(render_soa)

	spatial_grid: [GRID_WIDTH][GRID_HEIGHT][dynamic]i32
	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_HEIGHT {
			spatial_grid[x][y] = make([dynamic]i32, 0, 128)
		}
	}

	//player init
	position_soa[current_no_entities] = {SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}
	movement_soa[current_no_entities] = Movement {
		direction = {0, 0},
		speed     = 100,
	}
	render_soa[current_no_entities] = {
		type  = EntityType.PLAYER,
		size  = 7,
		color = rl.BEIGE,
	}
	current_no_entities += 1

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Bullet Hell")
	rl.SetTargetFPS(60)


	for !rl.WindowShouldClose() {
		dt = rl.GetFrameTime()

		game_time += dt
		enemy_spawn_cooldown -= dt
		bullet_timer -= dt

		for x in 0 ..< GRID_WIDTH {
			for y in 0 ..< GRID_HEIGHT {
				clear(&spatial_grid[x][y])
			}
		}


		movement_soa[0].direction = {0, 0}
		if rl.IsKeyDown(rl.KeyboardKey.UP) {
			movement_soa[0].direction.y = -1
		};if rl.IsKeyDown(rl.KeyboardKey.DOWN) {movement_soa[0].direction.y = 1
		}
		if rl.IsKeyDown(rl.KeyboardKey.LEFT) {
			movement_soa[0].direction.x = -1
		}
		if rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
			movement_soa[0].direction.x = 1
		}
		movement_soa[0].direction = rl.Vector2Normalize(movement_soa[0].direction)

		//TODO: Remove bool?
		for i in 0 ..< current_no_entities {
			if render_soa[i].to_be_removed {
				last_index := current_no_entities - 1
				position_soa[i] = position_soa[last_index]
				movement_soa[i] = movement_soa[last_index]
				render_soa[i] = render_soa[last_index]

				current_no_entities -= 1
			}
		}


		if enemy_spawn_cooldown <= 0 && current_no_entities < MAX_ENTITIES {

			for i in 0 ..< 512 {
				if current_no_entities >= MAX_ENTITIES do break
				position_soa[current_no_entities] = get_rand_pos_around_pt(
					position_soa[0],
					200,
					400,
				)
				movement_soa[current_no_entities] = {
					speed     = 35,
					direction = {0, 0},
				}
				render_soa[current_no_entities] = {
					type  = EntityType.ENEMY,
					color = rl.BROWN,
					size  = 15,
				}

				current_no_entities += 1
				enemy_spawn_cooldown = INITIAL_SPAWN_COOLDOWN
			}

		}


		if bullet_timer <= 0 && current_no_entities < MAX_ENTITIES {
			for i in 0 ..< 22 {
				if current_no_entities >= MAX_ENTITIES do break

				angle := f32(i) * (2 * math.PI / 22)
				bullet_offset := rl.Vector2{20 * math.cos(angle), 20 * math.sin(angle)}

				position_soa[current_no_entities] = position_soa[0] + bullet_offset
				movement_soa[current_no_entities] = {
					direction = rl.Vector2{math.cos(angle), math.sin(angle)},
					speed     = 200,
				}
				render_soa[current_no_entities] = {
					type  = EntityType.BULLET,
					color = rl.BEIGE,
					size  = 3,
				}
				current_no_entities += 1
			}

			bullet_timer = INITIAL_BULLET_COOLDOWN
		}

		for i := 1; i < current_no_entities; i += 1 {
			if render_soa[i].type == EntityType.ENEMY {
				dir := position_soa[0] - position_soa[i]
				movement_soa[i].direction = rl.Vector2Normalize(dir)
			}
		}

		for i := 0; i < current_no_entities; i += 1 {
			position_soa[i].x += movement_soa[i].direction.x * movement_soa[i].speed * dt
			position_soa[i].y += movement_soa[i].direction.y * movement_soa[i].speed * dt
		}

		for i in 0 ..< current_no_entities {
			add_to_grid(&spatial_grid, i32(i), position_soa[i])
		}

		check_collisions(
			&spatial_grid,
			&position_soa,
			&movement_soa,
			&render_soa,
			&current_no_entities,
		)

		rl.BeginDrawing()

		rl.ClearBackground(rl.DARKGRAY)


		for i := 0; i < current_no_entities; i += 1 {
			switch render_soa[i].type {
			case .PLAYER:
				rl.DrawCircleV(position_soa[i], render_soa[i].size, render_soa[i].color)
			case .BULLET:
				rl.DrawCircleV(position_soa[i], render_soa[i].size, render_soa[i].color)
			case .ENEMY:
				rl.DrawRectangleV(
					position_soa[i],
					{render_soa[i].size, render_soa[i].size},
					render_soa[i].color,
				)
			}
		}

		rl.DrawText(fmt.ctprintf("%d", current_no_entities), 10, 20, 24, rl.WHITE)
		rl.DrawText(fmt.ctprintf("%d", rl.GetFPS()), SCREEN_WIDTH - 80, 20, 24, rl.WHITE)
		rl.EndDrawing()

	}


}


get_rand_pos_around_pt :: proc(pt: rl.Vector2, min_dist: f32, max_dist: f32) -> rl.Vector2 {
	angle := rand.float32_range(0, 360) * (math.PI / 180.0)
	distance := min_dist + rand.float32() * (max_dist - min_dist)
	spawn_offset := rl.Vector2{distance * math.cos(angle), distance * math.sin(angle)}
	return pt + spawn_offset
}

add_to_grid :: proc(
	grid: ^[GRID_WIDTH][GRID_HEIGHT][dynamic]i32,
	entity_idx: i32,
	pos: rl.Vector2,
) {
	grid_x, grid_y := vec_to_cords(pos)
	append(&grid[grid_x][grid_y], entity_idx)
}

vec_to_cords :: proc(pos: rl.Vector2) -> (i32, i32) {
	grid_x := i32(pos.x / GRID_CELL_SIZE)
	grid_y := i32(pos.y / GRID_CELL_SIZE)
	return clamp(grid_x, 0, GRID_WIDTH - 1), clamp(grid_y, 0, GRID_HEIGHT - 1)
}

check_collisions :: proc(
	grid: ^[GRID_WIDTH][GRID_HEIGHT][dynamic]i32,
	position_soa: ^#soa[dynamic]rl.Vector2,
	movement_soa: ^#soa[dynamic]Movement,
	render_soa: ^#soa[dynamic]RenderInfo,
	current_no_entities: ^int,
) {

	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_HEIGHT {
			cell := &grid[x][y]
			for i in 0 ..< len(cell) {
				entity1_idx := cell[i]
				if int(entity1_idx) >= current_no_entities^ do continue
				if render_soa[entity1_idx].type != EntityType.BULLET do continue

				maxx, minx, maxy, miny: int

				modx := int(position_soa[entity1_idx].x) % GRID_CELL_SIZE

				if modx == 0 {
					minx = 0
					maxx = 0
				} else if modx < 8 {
					minx = -1
					maxx = 0
				} else {
					minx = 0
					maxx = 1
				}
				mody := int(position_soa[entity1_idx].x) % GRID_CELL_SIZE

				if mody == 0 {
					miny = 0
					maxy = 0
				} else if modx < 8 {
					miny = -1
					maxy = 0
				} else {
					miny = 0
					maxy = 1
				}


				for dx in minx ..= maxx {
					for dy in miny ..= maxy {
						check_x := x + dx
						check_y := y + dy

						if check_x < 0 || check_x >= GRID_WIDTH || check_y < 0 || check_y >= GRID_HEIGHT do continue

						check_cell := &grid[check_x][check_y]

						for entity2_i in 0 ..< len(check_cell) {
							entity2_idx := check_cell[entity2_i]
							if render_soa[entity2_idx].type != EntityType.ENEMY do continue
							if int(entity2_idx) >= current_no_entities^ do continue
							if entity1_idx == entity2_idx do continue

							type1 := render_soa[entity1_idx].type
							type2 := render_soa[entity2_idx].type

							bullet_idx, enemy_idx: i32 = -1, -1

							if type1 == .BULLET && type2 == .ENEMY {
								bullet_idx = entity1_idx
								enemy_idx = entity2_idx
							} else if type1 == .ENEMY && type2 == .BULLET {
								bullet_idx = entity2_idx
								enemy_idx = entity1_idx
							}

							if bullet_idx != -1 && enemy_idx != -1 {

								if rl.CheckCollisionCircleRec(
									position_soa[bullet_idx],
									render_soa[bullet_idx].size,
									rl.Rectangle {
										position_soa[enemy_idx].x,
										position_soa[enemy_idx].y,
										render_soa[enemy_idx].size,
										render_soa[enemy_idx].size,
									},
								) {

									render_soa[bullet_idx].to_be_removed = true
									render_soa[enemy_idx].to_be_removed = true

								}
							}
						}
					}
				}
			}
		}
	}
}
