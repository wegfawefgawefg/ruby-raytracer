class Vec3
  attr_reader :x, :y, :z

  def initialize(x = 0.0, y = 0.0, z = 0.0)
    @x = x.to_f
    @y = y.to_f
    @z = z.to_f
  end

  def +(other)
    other = Vec3.coerce_value(other)
    Vec3.new(x + other.x, y + other.y, z + other.z)
  end

  def -(other)
    other = Vec3.coerce_value(other)
    Vec3.new(x - other.x, y - other.y, z - other.z)
  end

  def -@
    Vec3.new(-x, -y, -z)
  end

  def *(other)
    return Vec3.new(x * other, y * other, z * other) if other.is_a?(Numeric)

    other = Vec3.coerce_value(other)
    Vec3.new(x * other.x, y * other.y, z * other.z)
  end

  def /(other)
    Vec3.new(x / other, y / other, z / other)
  end

  def dot(other)
    other = Vec3.coerce_value(other)
    x * other.x + y * other.y + z * other.z
  end

  def cross(other)
    other = Vec3.coerce_value(other)
    Vec3.new(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x
    )
  end

  def length
    Math.sqrt(dot(self))
  end

  def normalize
    len = length
    return Vec3.new if len <= 0.000001

    self / len
  end

  def abs
    Vec3.new(x.abs, y.abs, z.abs)
  end

  def max(value)
    Vec3.new([x, value].max, [y, value].max, [z, value].max)
  end

  def to_a
    [x, y, z]
  end

  def self.coerce_value(value)
    return value if value.is_a?(Vec3)

    raise TypeError, "expected Vec3, got #{value.class}"
  end
end
