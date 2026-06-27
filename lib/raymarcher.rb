require_relative "vec3"

class Raymarcher
  MAX_STEPS = 96
  MAX_DIST = 8.0
  SURFACE_DIST = 0.0008

  def initialize(width:, height:)
    @width = width
    @height = height
    @aspect = width.to_f / height
  end

  def color_at(x, y, time)
    u = ((x + 0.5) / @width) * 2.0 - 1.0
    v = 1.0 - ((y + 0.5) / @height) * 2.0
    u *= @aspect

    camera = orbit_camera(time)
    target = Vec3.new(0.0, 0.15, 0.0)
    direction = ray_direction(camera, target, u, v)
    color = trace(camera, direction, time, 0)
    tone_map(color)
  end

  private

  def orbit_camera(time)
    orbit = 2.9
    yaw = time * 0.35
    Vec3.new(
      orbit * Math.cos(yaw),
      0.9 + 0.15 * Math.sin(time * 0.17),
      orbit * Math.sin(yaw)
    )
  end

  def trace(origin, direction, time, depth)
    hit = march(origin, direction, time)
    return sky(direction) unless hit[:hit]

    point = origin + direction * hit[:distance]
    normal = estimate_normal(point, time)
    color = shade(point, normal, direction, hit[:material], hit[:steps], time)

    if hit[:material] == :mirror && depth < 1
      reflected = reflect(direction, normal).normalize
      reflection = trace(point + normal * 0.025, reflected, time, depth + 1)
      color = color * 0.35 + reflection * 0.65
    end

    color
  end

  def ray_direction(camera, target, u, v)
    forward = (target - camera).normalize
    right = forward.cross(Vec3.new(0, 1, 0)).normalize
    up = right.cross(forward)
    (forward * 2.0 + right * u + up * v).normalize
  end

  def march(origin, direction, time)
    distance = 0.0
    material = :none

    MAX_STEPS.times do |step|
      point = origin + direction * distance
      sample = scene(point, time)
      material = sample[:material]

      return { hit: true, distance: distance, steps: step, material: material } if sample[:distance] < SURFACE_DIST

      distance += sample[:distance]
      break if distance > MAX_DIST
    end

    { hit: false, distance: distance, steps: MAX_STEPS, material: material }
  end

  def scene(point, time)
    center_sphere = wobbly_sphere(point, Vec3.new(0.0, 0.35, 0.0), 1.0, time)
    left_sphere = sphere(point - Vec3.new(-1.45, -0.28, 0.85), 0.32)
    right_sphere = sphere(point - Vec3.new(1.25, -0.35, -0.75), 0.28)
    floor = point.y + 1.0

    nearest = [
      { distance: center_sphere, material: :mirror },
      { distance: left_sphere, material: :red },
      { distance: right_sphere, material: :blue },
      { distance: floor, material: :floor }
    ].min_by { |sample| sample[:distance] }

    nearest
  end

  def sphere(point, radius)
    point.length - radius
  end

  def wobbly_sphere(point, center, radius, time)
    local = point - center
    local.length - radius +
      Math.sin(local.x * 12.0 + time * 1.4) * 0.025 +
      Math.cos(local.y * 13.0 + time * 1.1) * 0.025
  end

  def estimate_normal(point, time)
    e = 0.002
    dx = scene(point + Vec3.new(e, 0, 0), time)[:distance] - scene(point - Vec3.new(e, 0, 0), time)[:distance]
    dy = scene(point + Vec3.new(0, e, 0), time)[:distance] - scene(point - Vec3.new(0, e, 0), time)[:distance]
    dz = scene(point + Vec3.new(0, 0, e), time)[:distance] - scene(point - Vec3.new(0, 0, e), time)[:distance]
    Vec3.new(dx, dy, dz).normalize
  end

  def shade(point, normal, view_dir, material, steps, time)
    light_dir = Vec3.new(-0.35, 0.82, -0.52).normalize
    diffuse = [normal.dot(light_dir), 0.0].max
    half_vec = (light_dir - view_dir).normalize
    specular = [normal.dot(half_vec), 0.0].max ** 24.0
    rim = (1.0 - [normal.dot(-view_dir), 0.0].max) ** 2.0
    ambient = 0.12
    shadow = soft_shadow(point + normal * 0.02, light_dir, time)
    ao = 1.0 - steps / MAX_STEPS.to_f * 0.35

    base = case material
           when :mirror then Vec3.new(0.95, 0.35, 0.22)
           when :red then Vec3.new(0.95, 0.18, 0.1)
           when :blue then Vec3.new(0.1, 0.34, 1.0)
           else checker(point)
           end

    color = base * (ambient + diffuse * shadow * 0.85) * ao
    color += Vec3.new(1.0, 0.92, 0.78) * specular * shadow * (material == :mirror ? 0.95 : 0.45)
    color += Vec3.new(0.25, 0.45, 0.9) * rim * 0.18
    color
  end

  def soft_shadow(origin, direction, time)
    result = 1.0
    distance = 0.04

    20.times do
      point = origin + direction * distance
      h = scene(point, time)[:distance]
      return 0.12 if h < 0.001

      result = [result, 10.0 * h / distance].min
      distance += h.clamp(0.025, 0.42)
      break if distance > 7.0
    end

    result.clamp(0.12, 1.0)
  end

  def checker(point)
    cell = ((point.x * 1.35).floor + (point.z * 1.35).floor).even? ? 1.0 : 0.0
    cell == 1.0 ? Vec3.new(0.24, 0.29, 0.33) : Vec3.new(0.14, 0.18, 0.21)
  end

  def sky(direction)
    t = (direction.y * 0.5 + 0.5).clamp(0.0, 1.0)
    a = Vec3.new(0.025, 0.03, 0.05)
    b = Vec3.new(0.28, 0.38, 0.55)
    a * (1.0 - t) + b * t
  end

  def reflect(direction, normal)
    direction - normal * (2.0 * direction.dot(normal))
  end

  def tone_map(color)
    mapped = Vec3.new(
      color.x / (1.0 + color.x),
      color.y / (1.0 + color.y),
      color.z / (1.0 + color.z)
    )
    [
      (mapped.x.clamp(0.0, 1.0) * 255).round,
      (mapped.y.clamp(0.0, 1.0) * 255).round,
      (mapped.z.clamp(0.0, 1.0) * 255).round
    ]
  end
end
