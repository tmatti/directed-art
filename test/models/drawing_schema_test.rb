# frozen_string_literal: true

require "test_helper"

# Unit tests for the pure-function DSL validator that guards every generation
# against the Primitive contract (ADR-0001, ADR-0006) before it is persisted.
class DrawingSchemaTest < ActiveSupport::TestCase
  # A well-formed structured drawing, the shape the spike validated and the
  # faked generator emits. Helpers below mutate a copy to build malformed cases.
  def valid_drawing
    {
      "subject" => "a happy sun",
      "title" => "Let's draw a happy sun!",
      "canvas" => { "width" => 600, "height" => 600 },
      "steps" => [
        {
          "instruction" => "Draw a big circle.",
          "narration" => "A big round circle!",
          "primitives" => [
            { "type" => "circle", "cx" => 300, "cy" => 300, "r" => 120, "color" => "#ffd23f" }
          ]
        },
        {
          "instruction" => "Add pointy rays.",
          "narration" => "Pointy rays!",
          "primitives" => [
            { "type" => "polygon", "points" => [ [ 300, 150 ], [ 285, 180 ], [ 315, 180 ] ] },
            { "type" => "arc", "cx" => 300, "cy" => 320, "r" => 45, "start" => 20, "end" => 160 },
            { "type" => "line", "x1" => 10, "y1" => 10, "x2" => 590, "y2" => 590 },
            { "type" => "ellipse", "cx" => 200, "cy" => 200, "rx" => 50, "ry" => 30, "rotate" => 15 },
            { "type" => "polyline", "points" => [ [ 0, 0 ], [ 100, 100 ] ] },
            { "type" => "curve", "points" => [ [ 0, 0 ], [ 100, 100 ], [ 200, 0 ] ], "closed" => true }
          ]
        }
      ]
    }
  end

  test "a well-formed drawing across the whole primitive vocabulary passes" do
    assert_empty DrawingSchema.validate(valid_drawing)
    assert DrawingSchema.valid?(valid_drawing)
  end

  # --- Top-level structure ---

  test "a non-object drawing is rejected" do
    assert_not DrawingSchema.valid?([])
    assert_not DrawingSchema.valid?(nil)
    assert_not DrawingSchema.valid?("nope")
  end

  test "a missing subject or title is rejected" do
    assert_not DrawingSchema.valid?(valid_drawing.except("subject"))
    assert_not DrawingSchema.valid?(valid_drawing.except("title"))
    assert_not DrawingSchema.valid?(valid_drawing.merge("title" => "  "))
  end

  test "missing steps is rejected" do
    assert_not DrawingSchema.valid?(valid_drawing.except("steps"))
  end

  test "an empty steps array is rejected" do
    assert_not DrawingSchema.valid?(valid_drawing.merge("steps" => []))
  end

  test "a non-array steps value is rejected" do
    assert_not DrawingSchema.valid?(valid_drawing.merge("steps" => "circle"))
  end

  # --- Step structure ---

  test "a step missing its instruction is rejected" do
    drawing = valid_drawing
    drawing["steps"][0].delete("instruction")
    assert_not DrawingSchema.valid?(drawing)
  end

  test "a step with a blank instruction is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["instruction"] = "   "
    assert_not DrawingSchema.valid?(drawing)
  end

  test "a step with no primitives is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["primitives"] = []
    assert_not DrawingSchema.valid?(drawing)
  end

  # --- Primitive vocabulary ---

  test "an unknown primitive type is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["primitives"] = [ { "type" => "blob", "cx" => 10, "cy" => 10, "r" => 5 } ]
    assert_not DrawingSchema.valid?(drawing)
  end

  test "a primitive missing its type is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["primitives"] = [ { "cx" => 10, "cy" => 10, "r" => 5 } ]
    assert_not DrawingSchema.valid?(drawing)
  end

  # --- Malformed fields ---

  test "a circle missing a required field is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["primitives"] = [ { "type" => "circle", "cx" => 10, "cy" => 10 } ]
    assert_not DrawingSchema.valid?(drawing)
  end

  test "a non-numeric coordinate is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["primitives"] = [ { "type" => "circle", "cx" => "lots", "cy" => 10, "r" => 5 } ]
    assert_not DrawingSchema.valid?(drawing)
  end

  test "a non-positive radius is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["primitives"] = [ { "type" => "circle", "cx" => 10, "cy" => 10, "r" => 0 } ]
    assert_not DrawingSchema.valid?(drawing)
  end

  test "a polygon with too few points is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["primitives"] = [ { "type" => "polygon", "points" => [ [ 10, 10 ], [ 20, 20 ] ] } ]
    assert_not DrawingSchema.valid?(drawing)
  end

  test "a malformed point (not an x/y pair) is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["primitives"] = [ { "type" => "polyline", "points" => [ [ 10, 10 ], [ 20 ] ] } ]
    assert_not DrawingSchema.valid?(drawing)
  end

  # --- Out-of-canvas coordinates ---

  test "a coordinate beyond the canvas width is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["primitives"] = [ { "type" => "circle", "cx" => 700, "cy" => 300, "r" => 50 } ]
    assert_not DrawingSchema.valid?(drawing)
  end

  test "a negative coordinate is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["primitives"] = [ { "type" => "circle", "cx" => 300, "cy" => -5, "r" => 50 } ]
    assert_not DrawingSchema.valid?(drawing)
  end

  test "a point outside the canvas is rejected" do
    drawing = valid_drawing
    drawing["steps"][0]["primitives"] = [ { "type" => "polygon", "points" => [ [ 0, 0 ], [ 300, 0 ], [ 300, 999 ] ] } ]
    assert_not DrawingSchema.valid?(drawing)
  end

  test "coordinates are bounded by the drawing's own canvas dimensions" do
    drawing = valid_drawing.merge("canvas" => { "width" => 800, "height" => 800 })
    drawing["steps"][0]["primitives"] = [ { "type" => "circle", "cx" => 700, "cy" => 700, "r" => 50 } ]
    assert DrawingSchema.valid?(drawing)
  end

  test "canvas dimensions default to 600 when omitted" do
    drawing = valid_drawing.except("canvas")
    drawing["steps"][0]["primitives"] = [ { "type" => "circle", "cx" => 599, "cy" => 599, "r" => 10 } ]
    assert DrawingSchema.valid?(drawing)

    drawing["steps"][0]["primitives"] = [ { "type" => "circle", "cx" => 601, "cy" => 300, "r" => 10 } ]
    assert_not DrawingSchema.valid?(drawing)
  end

  # --- validate! raises for the job pipeline ---

  test "validate! returns the drawing when valid" do
    assert_equal valid_drawing, DrawingSchema.validate!(valid_drawing)
  end

  test "validate! raises InvalidDrawing listing the problems when malformed" do
    error = assert_raises(DrawingSchema::InvalidDrawing) do
      DrawingSchema.validate!(valid_drawing.except("steps"))
    end
    assert_match(/steps/, error.message)
  end
end
