# frozen_string_literal: true

# The pure-function validator for the constrained Primitive DSL (ADR-0001).
# Every structured drawing — whoever generated it — is checked against this
# contract before it is persisted, so a provider or model swap can never
# silently produce a broken drawing (ADR-0006). It depends on nothing but the
# parsed JSON hash (string keys, as the LLM emits) and returns a list of human
# problems; an empty list means the drawing is well-formed.
module DrawingSchema
  # Raised by validate! so the generation job can retry/reject malformed output.
  class InvalidDrawing < StandardError; end

  # The canvas a drawing falls back to when it omits its own (matches the model
  # and the spike: a fixed 600×600 square).
  DEFAULT_DIMENSION = 600

  # The full Primitive vocabulary and each type's field contract:
  #   x / y    coordinate fields, bounds-checked against the canvas axis
  #   lengths  radii — must be positive numbers
  #   numbers  free scalars (angles, rotation) — must be numbers when present
  #   points   carries a [[x, y], …] list with this many points minimum
  # Anything not listed (e.g. an optional `color`) is ignored: the renderer
  # treats it as advisory, so it can never make a drawing invalid.
  SHAPES = {
    "circle"   => { x: %w[cx], y: %w[cy], lengths: %w[r], numbers: [] },
    "ellipse"  => { x: %w[cx], y: %w[cy], lengths: %w[rx ry], numbers: %w[rotate] },
    "line"     => { x: %w[x1 x2], y: %w[y1 y2], lengths: [], numbers: [] },
    "arc"      => { x: %w[cx], y: %w[cy], lengths: %w[r], numbers: %w[start end] },
    "polyline" => { points: 2 },
    "polygon"  => { points: 3 },
    "curve"    => { points: 2 }
  }.freeze

  class << self
    def valid?(drawing)
      validate(drawing).empty?
    end

    # Returns the drawing unchanged when valid; raises InvalidDrawing otherwise.
    def validate!(drawing)
      errors = validate(drawing)
      raise InvalidDrawing, errors.join("; ") unless errors.empty?

      drawing
    end

    # The list of human-readable problems with `drawing` (empty when well-formed).
    def validate(drawing)
      return [ "drawing must be an object" ] unless drawing.is_a?(Hash)

      errors = []
      errors << "subject is required" if blank?(drawing["subject"])
      errors << "title is required" if blank?(drawing["title"])

      width = dimension(drawing.dig("canvas", "width"))
      height = dimension(drawing.dig("canvas", "height"))

      steps = drawing["steps"]
      unless steps.is_a?(Array) && steps.any?
        errors << "steps must be a non-empty array"
        return errors
      end

      steps.each_with_index do |step, i|
        errors.concat(step_errors(step, width, height, "step #{i + 1}"))
      end
      errors
    end

    private

    def step_errors(step, width, height, label)
      return [ "#{label} must be an object" ] unless step.is_a?(Hash)

      errors = []
      errors << "#{label} instruction is required" if blank?(step["instruction"])

      primitives = step["primitives"]
      unless primitives.is_a?(Array) && primitives.any?
        return errors << "#{label} must have at least one primitive"
      end

      primitives.each_with_index do |primitive, j|
        errors.concat(primitive_errors(primitive, width, height, "#{label} primitive #{j + 1}"))
      end
      errors
    end

    def primitive_errors(primitive, width, height, label)
      return [ "#{label} must be an object" ] unless primitive.is_a?(Hash)

      shape = SHAPES[primitive["type"]]
      return [ "#{label} has unknown type #{primitive["type"].inspect}" ] unless shape

      errors = []
      Array(shape[:x]).each { |f| errors << "#{label} #{f} is out of canvas" unless in_bounds?(primitive[f], width) }
      Array(shape[:y]).each { |f| errors << "#{label} #{f} is out of canvas" unless in_bounds?(primitive[f], height) }
      Array(shape[:lengths]).each { |f| errors << "#{label} #{f} must be a positive number" unless positive?(primitive[f]) }
      Array(shape[:numbers]).each { |f| errors << "#{label} #{f} must be a number" unless primitive[f].nil? || number?(primitive[f]) }
      errors.concat(points_errors(primitive["points"], shape[:points], width, height, label)) if shape[:points]
      errors
    end

    def points_errors(points, minimum, width, height, label)
      unless points.is_a?(Array) && points.size >= minimum
        return [ "#{label} needs at least #{minimum} points" ]
      end

      points.each_with_index.filter_map do |point, i|
        unless point.is_a?(Array) && point.size == 2 && in_bounds?(point[0], width) && in_bounds?(point[1], height)
          "#{label} point #{i + 1} is out of canvas or malformed"
        end
      end
    end

    def dimension(value)
      number?(value) && value.positive? ? value : DEFAULT_DIMENSION
    end

    def in_bounds?(value, max)
      number?(value) && value >= 0 && value <= max
    end

    def positive?(value)
      number?(value) && value.positive?
    end

    def number?(value)
      value.is_a?(Numeric)
    end

    def blank?(value)
      value.to_s.strip.empty?
    end
  end
end
