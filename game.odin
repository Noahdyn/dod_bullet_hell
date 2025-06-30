package main

import "core:fmt"
import math "core:math"
import rand "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
MAX_ENTITIES :: 100000

GRID_CELL_SIZE :: 32
GRID_WIDTH :: (SCREEN_WIDTH / GRID_CELL_SIZE) + 1
GRID_HEIGHT :: (SCREEN_HEIGHT / GRID_CELL_SIZE) + 1

EntityType :: enum {
	PLAYER,
	BULLET,
	ENEMY,
}

RenderInfo :: struct {
	type:  EntityType,
	color: rl.Color,
	size:  f32,
}

Movement :: struct {
	direction: rl.Vector2,
	speed:     f32,
}


main :: proc() {
	dt: f32
	game_time: f32 = 0
	current_no_entities := 0
	enemy_spawn_cooldown: f32 = 0.12
	bullet_timer: f32 = 0.3
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
			spatial_grid[x][y] = make([dynamic]i32)
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
		fmt.println(current_no_entities)
		fmt.println(rl.GetFPS())
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

		if enemy_spawn_cooldown <= 0 && current_no_entities < MAX_ENTITIES {

			for i in 0 ..< 16 {
				if current_no_entities >= MAX_ENTITIES do break
				position_soa[current_no_entities] = get_rand_pos_around_pt(
					position_soa[0],
					200,
					400,
				)
				movement_soa[current_no_entities] = {
					speed     = 55,
					direction = {0, 0},
				}
				render_soa[current_no_entities] = {
					type  = EntityType.ENEMY,
					color = rl.BROWN,
					size  = 15,
				}

				current_no_entities += 1
				enemy_spawn_cooldown = 0.05
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

			bullet_timer = 0.072
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

				for dx in -1 ..= 1 {
					for dy in -1 ..= 1 {
						check_x := x + dx
						check_y := y + dy

						if check_x < 0 || check_x >= GRID_WIDTH || check_y < 0 || check_y >= GRID_HEIGHT do continue

						check_cell := &grid[check_x][check_y]

						for entity2_i in 0 ..< len(check_cell) {
							entity2_idx := check_cell[entity2_i]
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

									remove_entity(
										bullet_idx,
										current_no_entities,
										position_soa,
										movement_soa,
										render_soa,
									)

									remove_entity(
										enemy_idx,
										current_no_entities,
										position_soa,
										movement_soa,
										render_soa,
									)

								}
							}
						}
					}
				}
			}
		}
	}
}


remove_entity :: proc(
	index: i32,
	current_no_entities: ^int,
	position_soa: ^#soa[dynamic]rl.Vector2,
	movement_soa: ^#soa[dynamic]Movement,
	render_soa: ^#soa[dynamic]RenderInfo,
) {
	last_index := current_no_entities^ - 1

	position_soa[index] = position_soa[last_index]
	movement_soa[index] = movement_soa[last_index]
	render_soa[index] = render_soa[last_index]

	current_no_entities^ -= 1
}
