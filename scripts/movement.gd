extends CharacterBody3D

@export_category("Controls")
@export var look_enabled : bool = true:
	get:
		return move_enabled
	set(val):
		look_enabled = val
		update_mouse_mode()
@export var move_enabled : bool = true
@export var jump_when_held : bool = true
@export_category("Input Definition")
@export var sensitivity : Vector2 = Vector2.ONE

@export_category("Movement Variables")
var jump_amount : int = 2
@export var max_jump_amount : int = 2
@export var gravity : float = 30
@export var ground_accel : float = 50
@export var air_accel : float = 15
@export var max_ground_vel : float = 20
@export var max_air_vel : float = 800
@export var jump_force : float = 1
@export var friction : float = 6
@export var additive_hop : bool = true
@export var crouching : bool = false
@export var soft_speed_cap : float = 100
@export var stopping_time: float = .5
@export var jump_time :float = 5
@export var jump_wait_time : float = 10
@export var wall_fall_speed : float = 5
@export var wall_fall_mult : float = 2


@export_category("Slide")
@export var slide_accel : float = 250
@export var max_slide_vel : float = 1000
@export var sliding : bool = false
@export var just_sliding: bool = false
@export var max_slide_time : float = 2.5
@export var slide_needed_vel: float = 5
@export var slide_stop_needed_vel: float = 2
@export var slide_height: float = .5
@export var slide_ease_time: float = 1
@export var time_since_slide: float = 0
@export var slide_ease_out_time: float = 1
@export var slide_friction: float = 2
@export var slide_ignore_friction_speed: float = 20
@export var slide_ignore_friction_time: float = 1

var norm_height: float = 1

@export_category("Nodes")
@export var camera : Camera3D
@export var norm_shape : CollisionShape3D

var stopped_time : float = 0
var slide_time : float = 0

func update_mouse_mode():
	if look_enabled && camera:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
	else: 
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func mouse_look(event):
	if look_enabled && camera:
		if event == InputEventMouseMotion:
			print(event.relative.x + ": mouse x")
			rotate_y(deg_to_rad(-event.relative.x * sensitivity.y))
			camera.rotate_x(deg_to_rad(-event.relative.y * sensitivity.x))
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func get_wishdir():
	if !move_enabled:
		return Vector3.ZERO
	elif (velocity.z + velocity.x) > soft_speed_cap:
		print("hitting soft speedcap")
		return Vector3.ZERO + \
		(transform.basis.z * Input.get_axis("Forward", "Backward") * (soft_speed_cap/velocity.length())) +\
		(transform.basis.x * Input.get_axis("Left", "Right") * (soft_speed_cap/velocity.length()))
	else: return Vector3.ZERO + \
		(transform.basis.z * Input.get_axis("Forward", "Backward")) +\
		(transform.basis.x * Input.get_axis("Left", "Right"))

func get_jump():
	return sqrt(4 * jump_force * gravity)
		


func accelleration(accel_dir, prevVelocity, acceleration, max_vel, delta):
	var projVel:float = prevVelocity.dot(accel_dir)
	var accelVel:float = acceleration * delta
	
	if((projVel + accelVel) > max_vel):
		accelVel = max_vel - projVel;
	
	print(prevVelocity + accel_dir*accelVel)
	
	return prevVelocity + accel_dir*accelVel


func get_next_velocity(prevVel, delta):
	var grounded = is_on_floor()
	var can_jump = (jump_time > jump_wait_time if !is_on_floor() else true)
	
	
	var our_velocity = prevVel
	if grounded && !sliding:
		our_velocity = moveGround(get_wishdir(), prevVel, delta)
	elif grounded && just_sliding:
		our_velocity = moveJustSlide(get_wishdir(), prevVel, delta)
	elif grounded && sliding:
		our_velocity = moveSlide(get_wishdir(), prevVel, delta)
	elif !grounded && is_on_wall():
		our_velocity = moveGround(get_wishdir(), prevVel, delta)
	else:
		our_velocity = moveAir(get_wishdir(), prevVel, delta)
	
	our_velocity = calc_gravity(our_velocity, delta)
	if((Input.is_action_pressed("Jump") if jump_when_held else Input.is_action_just_pressed("Jump")) && move_enabled && can_jump && jump_amount > 0):
		#print(jump_amount)
		if !grounded:
			air_kick(get_wishdir(), prevVel, delta)
		jump_amount -= 1
		jump_time = 0
		our_velocity.y = get_jump()
		
	
	return our_velocity

func calc_gravity(our_velocity, delta):
	if is_on_wall() && abs(get_wall_normal().dot(transform.basis.x)) < .3:
		if our_velocity.length() < wall_fall_speed:
			our_velocity += Vector3.DOWN * delta
			return our_velocity
		else:
			our_velocity += Vector3.DOWN * (gravity * delta)/ wall_fall_mult
			return our_velocity
	our_velocity += Vector3.DOWN * (gravity * delta)
	return our_velocity
	

func air_kick(accelDir:Vector3, prevVelocity, delta):
	if accelDir.dot(prevVelocity) < 0:
		return accelleration(accelDir, Vector3(0,0,0), slide_accel, max_air_vel, delta)
	else:
		return accelleration(accelDir, prevVelocity, ground_accel, max_air_vel, delta)

func moveGround(accelDir, prevVelocity, delta):
	var speed:float = prevVelocity.length()
	if(speed != 0):
		var drop:float = speed * friction * delta
		prevVelocity *= max(speed - drop, 0) / speed # scale velocity by friction
		
	return accelleration(accelDir, prevVelocity, ground_accel, max_ground_vel, delta)

func moveSlide(accelDir, prevVelocity, delta):
	var speed:float = prevVelocity.length()
	if(speed!=0) && speed < slide_ignore_friction_speed && slide_time > slide_ignore_friction_time:
		var drop:float = speed * slide_friction * delta
		prevVelocity *= max(speed - drop, 0) /speed
	return accelleration(accelDir, prevVelocity, 0, max_slide_vel, delta)

func moveJustSlide(accelDir, prevVelocity, delta):
	return accelleration(accelDir, prevVelocity, slide_accel, max_slide_vel, delta)
	

func moveAir(accelDir, prevVelocity, delta):
	return accelleration(accelDir, prevVelocity, air_accel, max_air_vel, delta)

func update_frame_timer():
	if is_on_floor():
		jump_amount = max_jump_amount
		jump_time = 0
		if sliding:
			slide_time += 1
			return
		time_since_slide += 1
		slide_time = 0
	else: slide_time = 0; jump_time += 1

func handle_movement(delta):
	update_frame_timer()
	slide()
	velocity = get_next_velocity(velocity, delta)
	move_and_slide()

func _physics_process(delta: float) -> void:
	handle_movement(delta)

func _unhandled_input(event: InputEvent) -> void:
	mouse_look(event)
	if event.is_action_pressed("escape"):
		get_tree().quit()

func _ready() -> void:
	norm_height = scale.y
	update_mouse_mode()

func slide() -> void:
	if Input.is_action_just_pressed("slide") && ((abs(velocity.z) + abs(velocity.x)) > slide_needed_vel) && is_on_floor() && !sliding:
		sliding = true
		just_sliding = true
		
	elif Input.is_action_pressed("slide") && ((abs(velocity.z) + abs(velocity.x)) > slide_stop_needed_vel):
		just_sliding = false
		if norm_shape.scale.y != .5:
			var scaled =  norm_shape.scale.bezier_interpolate(Vector3(1,.9,1), Vector3(1,.6,1), Vector3(1,.5,1), min(slide_time/ slide_ease_time, 1))
			#print(scaled)
			norm_shape.set_deferred("scale", scaled)
	else:
		if sliding == true:
			sliding = false
		if norm_shape.scale.y != 1:
			var scaled =  norm_shape.scale.bezier_interpolate(Vector3(1,.6,1), Vector3(1,.9,1), Vector3(1,1,1), min(time_since_slide, 1))
			norm_shape.set_deferred("scale", scaled)
		
	

func root(n, s):
	#print(pow(n, (1/s)))
	return pow(n, (1/s))
