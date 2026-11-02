meta:
  id: rmv6
  application: xochitl
  file-extension: rm
  license: MIT
  encoding: UTF-8
  endian: le

doc: |
  Spec for the ReMarkable tablet's notebook/annotation file format.

  This spec recognizes only the current format (v6) utilized by ReMarkable
  firmware versions 3.x. See references for specs for previous versions.


seq:
  - id: header
    type: header
    doc: |
      Fixed 43-byte text header. The format version (which should always
      be 6) is the only information in it.

  - id: blocks
    type: block
    repeat: eos
    doc: |
      Blocks contain all data structures of the file, including the
      page-level preamble (`author_ids`, `migration_info`, `page_info`,
      `scene_info`) that earlier versions of this spec treated as fixed
      "frontmatter". See the `block_type` enum and `block` type.

enums:
  block_type:
    0x00:
      id: migration_info
      doc: Migration/device marker. See `migration_info`.
    0x01:
      id: scene_tree
      doc: |
        Declares a node in the scene tree (the root group, each layer)
        and its parent. One block per layer. See `scene_tree`.
    0x02:
      id: tree_node
      doc: |
        Properties of a scene tree node: label (layer name), visibility,
        and optional text anchoring. One block per layer. See
        `tree_node`.
    0x03:
      id: scene_glyph_item
      doc: Highlight over text in an underlying PDF/EPUB.
    0x04:
      id: scene_group_item
      doc: |
        Places a group (layer) into its parent's child list. One block per
        layer. See `scene_item`/`group_value`.
    0x05:
      id: scene_line_item
      doc: A pen stroke. See `scene_item`/`line_value`.
    0x06:
      id: scene_text_item
      doc: Text item in the scene tree (not the page's typed text).
    0x07:
      id: root_text
      doc: |
        The page's typed text. At most one block per page. See
        `root_text`.
    0x08:
      id: scene_tombstone_item
      doc: Placeholder for a deleted scene item.
    0x09:
      id: author_ids
      doc: |
        Maps the small integer author ids used in CRDT ids to UUIDs. See
        `author_ids`.
    0x0a:
      id: page_info
      doc: Page counters (loads, merges, text chars/lines, ...). See `page_info`.
    0x0d:
      id: scene_info
      doc: |
        Page-level scene state (current layer, visibility flags, ...). See
        `scene_info`.
    0x0e:
      id: image_table
      doc: |
        Images used on the page: maps an image key to the image file stored
        next to the page. See `image_table`.
    0x0f:
      id: scene_image_item
      doc: A placed image. See `scene_item`/`image_value`.

  tag_type:
    0x1:
      id: byte1
      doc: 1-byte value.
    0x4:
      id: byte4
      doc: 4-byte value (u4 or f4).
    0x8:
      id: byte8
      doc: 8-byte value (f8).
    0xc:
      id: length4
      doc: Sub-block, prefixed with a u4 byte length.
    0xf:
      id: id
      doc: A `crdt_id`.

  lww_kind:
    0: crdt_id
    1: u1
    2: f4
    3: string
    4: uuid
    5: rect

  inline_format:
    1: bold_start
    2: bold_end
    3: italic_start
    4: italic_end

  paragraph_style:
    0: basic
    1: plain
    2: heading
    3: bold
    4: bullet
    5: bullet2
    6: checkbox
    7: checkbox_checked

  pen:
    0: paintbrush_1
    1: pencil_1
    2: ballpoint_1
    3: marker_1
    4: fineliner_1
    5: highlighter_1
    6: eraser
    7: mechanical_pencil_1
    8: eraser_area
    12: paintbrush_2
    13: mechanical_pencil_2
    14: pencil_2
    15: ballpoint_2
    16: marker_2
    17: fineliner_2
    18: highlighter_2
    21: calligraphy
    23: shader

  pen_color:
    0: black
    1: gray
    2: white
    3: yellow
    4: green
    5: pink
    6: blue
    7: red
    8: gray_overlap
    9: highlight

types:

  # ------------------------------------------------------------------
  # Primitives
  #
  # Almost everything inside a block body is a sequence of tagged
  # values. A tag is a varuint `(index << 4) | tag_type`, where `index`
  # is the field number within the enclosing structure and `tag_type`
  # says how the value is encoded (see enum `tag_type`). Most of the
  # "magic" bytes seen in hex dumps (`1f`, `2f`, `3f`, `4f`, `54`, `6c`,
  # `5c`, ...) are tags. Fields are optional; a reader skips what it
  # doesn't know, and structures commonly gain new trailing fields in
  # newer firmware.
  # ------------------------------------------------------------------

  empty: {}

  varuint:
    doc: |
      Unsigned LEB128 integer: 7 bits per byte, least significant group
      first, high bit set on every byte but the last. Up to 8 bytes
      (56 bits) are decoded, enough for the 48-bit counters used.
    seq:
      - id: groups
        type: u1
        repeat: until
        repeat-until: (_ & 0x80) == 0
    instances:
      value:
        value: >-
          (groups[0] & 0x7f) |
          (groups.size > 1 ? (groups[1] & 0x7f).as<u8> << 7 : 0) |
          (groups.size > 2 ? (groups[2] & 0x7f).as<u8> << 14 : 0) |
          (groups.size > 3 ? (groups[3] & 0x7f).as<u8> << 21 : 0) |
          (groups.size > 4 ? (groups[4] & 0x7f).as<u8> << 28 : 0) |
          (groups.size > 5 ? (groups[5] & 0x7f).as<u8> << 35 : 0) |
          (groups.size > 6 ? (groups[6] & 0x7f).as<u8> << 42 : 0) |
          (groups.size > 7 ? (groups[7] & 0x7f).as<u8> << 49 : 0)

  tag:
    doc: |
      A field tag, validated against the expected field index and tag type.
      Encoded as varuint `(index << 4) | tag_type`; a single byte for
      index < 8.
    params:
      - id: expected_index
        type: u4
      - id: expected_type
        type: u1
    seq:
      - id: b0
        type: u1
        valid: '(((expected_index << 4) | expected_type) & 0x7f) | (expected_index >= 8 ? 0x80 : 0)'
      - id: b1
        type: u1
        if: expected_index >= 8
        valid: ((expected_index << 4) | expected_type) >> 7

  crdt_id:
    doc: |
      Identifier of an object (layer, stroke, text character, ...) or a
      Lamport-style timestamp. `author` indexes the `author_ids` block;
      `counter` increments per new object.

      These are the variable-length "id fields" of earlier versions of
      this spec: the length varies because `counter` is a varuint.
    seq:
      - id: author
        type: u1
      - id: counter
        type: varuint

  tagged_id:
    params:
      - id: index
        type: u4
    seq:
      - id: tag
        type: tag(index, 0xf)
      - id: value
        type: crdt_id

  tagged_u1:
    params:
      - id: index
        type: u4
    seq:
      - id: tag
        type: tag(index, 0x1)
      - id: value
        type: u1

  tagged_u4:
    params:
      - id: index
        type: u4
    seq:
      - id: tag
        type: tag(index, 0x4)
      - id: value
        type: u4

  tagged_f4:
    params:
      - id: index
        type: u4
    seq:
      - id: tag
        type: tag(index, 0x4)
      - id: value
        type: f4

  tagged_f8:
    params:
      - id: index
        type: u4
    seq:
      - id: tag
        type: tag(index, 0x8)
      - id: value
        type: f8

  tagged_string:
    params:
      - id: index
        type: u4
    seq:
      - id: tag
        type: tag(index, 0xc)
      - id: len_body
        type: u4
      - id: body
        size: len_body
        type: string_body

  tagged_s4:
    params:
      - id: index
        type: u4
    seq:
      - id: tag
        type: tag(index, 0x4)
      - id: value
        type: s4

  tagged_uuid:
    params:
      - id: index
        type: u4
    seq:
      - id: tag
        type: tag(index, 0xc)
      - id: len_value
        type: u4
      - id: value
        size: len_value
        doc: UUID in big-endian (RFC 4122) byte order.

  tagged_rect:
    params:
      - id: index
        type: u4
    seq:
      - id: tag
        type: tag(index, 0xc)
      - id: len_body
        type: u4
      - id: body
        size: len_body
        type: optional_rect

  optional_rect:
    doc: |
      Optional integer rectangle. Field layout from the Android app's
      decompiled code; only `has_value == 0` has been observed.
    seq:
      - id: has_value
        type: tagged_u1(1)
      - id: x
        type: tagged_s4(2)
        if: has_value.value != 0
      - id: y
        type: tagged_s4(3)
        if: has_value.value != 0
      - id: w
        type: tagged_s4(4)
        if: has_value.value != 0
      - id: h
        type: tagged_s4(5)
        if: has_value.value != 0
      - id: unknown_trailing
        size-eos: true

  string_body:
    seq:
      - id: len_value
        type: varuint
      - id: is_ascii
        type: u1
      - id: value
        type: str
        size: len_value.value
      - id: format
        type: tagged_u4(2)
        if: not _io.eof
        doc: |
          Inline formatting marker carried by an otherwise empty text item
          (the "$" byte in earlier versions of this spec is this field's
          tag). See enum `inline_format`.

  lww:
    doc: |
      Last-writer-wins register: a value plus the timestamp of its last
      write, used for mergeable properties.
    params:
      - id: index
        type: u4
      - id: kind
        type: u1
        enum: lww_kind
    seq:
      - id: tag
        type: tag(index, 0xc)
      - id: len_body
        type: u4
      - id: body
        size: len_body
        type: lww_body(kind)

  lww_body:
    params:
      - id: kind
        type: u1
        enum: lww_kind
    seq:
      - id: timestamp
        type: tagged_id(1)
      - id: value
        type:
          switch-on: kind
          cases:
            'lww_kind::crdt_id': tagged_id(2)
            'lww_kind::u1': tagged_u1(2)
            'lww_kind::f4': tagged_f4(2)
            'lww_kind::string': tagged_string(2)
            'lww_kind::uuid': tagged_uuid(2)
            'lww_kind::rect': tagged_rect(2)
      - id: unknown_trailing
        size-eos: true

  block:
    doc: |
      A block of data, storing some major structure of the format.

      Each block has an 8-byte header: the body length, one unknown byte,
      two version bytes, and the block type. The body follows.

    seq:
      - id: len_body
        type: u4
        doc: Byte count for block's main body.

      - id: unknown
        type: u1
        doc: Always 0 in observed files.

      - id: min_version
        type: u1
        doc: Oldest reader version that can parse this block.

      - id: current_version
        type: u1
        doc: |
          Version this block was written with. Selects the layout where it
          varies between versions (e.g. point size in `scene_line_item`).

      - id: block_type
        type: u1
        enum: block_type
        doc: Type of value stored in the block body. See enum `block_type`.

      - id: body
        size: len_body
        type:
          switch-on: block_type
          cases:
            'block_type::author_ids': author_ids
            'block_type::migration_info': migration_info
            'block_type::page_info': page_info
            'block_type::scene_info': scene_info
            'block_type::scene_tree': scene_tree
            'block_type::tree_node': tree_node
            'block_type::root_text': root_text
            'block_type::scene_group_item': scene_item(block_type, current_version)
            'block_type::scene_line_item': scene_item(block_type, current_version)
            'block_type::scene_image_item': scene_item(block_type, current_version)
            'block_type::image_table': image_table
            _: empty
        doc: Contains inner value of block.

  # ------------------------------------------------------------------
  # Block bodies
  # ------------------------------------------------------------------

  scene_tree:
    doc: Declares a scene tree node (root group or layer) and its parent.
    seq:
      - id: tree_id
        type: tagged_id(1)
      - id: node_id
        type: tagged_id(2)
      - id: is_update
        type: tagged_u1(3)
      - id: parent_tag
        type: tag(4, 0xc)
      - id: len_parent
        type: u4
      - id: parent
        size: len_parent
        type: scene_tree_parent
      - id: unknown_trailing
        size-eos: true

  scene_tree_parent:
    seq:
      - id: parent_id
        type: tagged_id(1)
      - id: unknown_trailing
        size-eos: true

  tree_node:
    doc: |
      Properties of a scene tree node. For layers, `label` is the layer
      name. Nodes anchored to typed text carry the optional anchor fields.
    seq:
      - id: node_id
        type: tagged_id(1)
      - id: label
        type: lww(2, lww_kind::string)
      - id: visible
        type: lww(3, lww_kind::u1)
      - id: anchor_id
        type: lww(7, lww_kind::crdt_id)
        if: not _io.eof
      - id: anchor_type
        type: lww(8, lww_kind::u1)
        if: not _io.eof
      - id: anchor_threshold
        type: lww(9, lww_kind::f4)
        if: not _io.eof
      - id: anchor_origin_x
        type: lww(10, lww_kind::f4)
        if: not _io.eof
      - id: unknown_trailing
        size-eos: true

  scene_item:
    doc: |
      Common wrapper for scene items (groups, strokes, ...). Items form a
      CRDT sequence inside their parent: `left_id`/`right_id` are the
      neighbours at insertion time. A deleted item keeps its ids, has a
      non-zero `deleted_length` and no `value`.
    params:
      - id: kind
        type: u1
        enum: block_type
      - id: version
        type: u1
    seq:
      - id: parent_id
        type: tagged_id(1)
      - id: item_id
        type: tagged_id(2)
      - id: left_id
        type: tagged_id(3)
      - id: right_id
        type: tagged_id(4)
      - id: deleted_length
        type: tagged_u4(5)
      - id: value
        type: scene_item_value(kind, version)
        if: not _io.eof

  scene_item_value:
    params:
      - id: kind
        type: u1
        enum: block_type
      - id: version
        type: u1
    seq:
      - id: tag
        type: tag(6, 0xc)
      - id: len_body
        type: u4
      - id: body
        size: len_body
        type:
          switch-on: kind
          cases:
            'block_type::scene_group_item': group_value
            'block_type::scene_line_item': line_value(version)
            'block_type::scene_image_item': image_value

  group_value:
    seq:
      - id: item_type
        type: u1
        valid: 2
      - id: node_id
        type: tagged_id(2)
        doc: The `scene_tree` node (layer) this item places.
      - id: unknown_trailing
        size-eos: true

  line_value:
    doc: |
      A "line" is typically the result of a single stroke of the tablet's
      stylus, and represents some line segment on the page. Lines include
      information about the pen type and color, and then are defined as a
      (long) array of individual points (`point`).

      Of the types in this spec, the line and point structs are the ones
      most similar to previous versions of the ReMarkable file format.
    params:
      - id: version
        type: u1
    seq:
      - id: item_type
        type: u1
        valid: 3
      - id: tool
        type: tagged_u4(1)
        doc: See enum `pen`.
      - id: color
        type: tagged_u4(2)
        doc: See enum `pen_color`.
      - id: thickness_scale
        type: tagged_f8(3)
      - id: starting_length
        type: tagged_f4(4)
      - id: points_tag
        type: tag(5, 0xc)
      - id: len_points
        type: u4
      - id: points
        size: len_points
        type: point_array(version)
      - id: timestamp
        type: tagged_id(6)
      - id: unknown_trailing
        size-eos: true
        doc: Newer firmware may append further fields (e.g. a move id).
    instances:
      tool_enum:
        value: tool.value
        enum: pen
      color_enum:
        value: color.value
        enum: pen_color

  point_array:
    params:
      - id: version
        type: u1
    seq:
      - id: points
        type: point(version)
        repeat: eos

  point:
    doc: |
      A struct representing a single point/dot on the screen, many of which
      make up a single line.

      Block version 1 stores every field after `y` as f4 (24 bytes per
      point); version 2 packs them into 14 bytes.
    params:
      - id: version
        type: u1
    seq:
      - id: x
        type: f4
        doc: X coordinate of the point. Origin is in the center of the page.
      - id: y
        type: f4
        doc: Y coordinate of the point. Origin is at the top of the page.
      - id: speed_v1
        type: f4
        if: version == 1
      - id: direction_v1
        type: f4
        if: version == 1
      - id: width_v1
        type: f4
        if: version == 1
      - id: pressure_v1
        type: f4
        if: version == 1
      - id: speed
        type: u2
        if: version != 1
        doc: |
          Speed the stylus was moving when this point was drawn. Used for
          rendering some pen types and influences the `width`.
      - id: width
        type: u2
        if: version != 1
        doc: Rendered width of the point on the screen.
      - id: direction
        type: u1
        if: version != 1
        doc: |
          Direction the stylus was moving when this point was drawn. "Direction"
          here is encoded as an angle mapped onto a single byte. For example,
          a value of 0 correlates to 0 degrees and a value of 255 correlates to
          360 degrees (or just under 360, rather). 0 degrees points to the right
          on the page and increases clockwise. So 90 degrees (or a value of
          255/4 = ~64) indicates moving downward.
      - id: pressure
        type: u1
        if: version != 1
        doc: |
          A value representing how hard the stylus was pressing on the screen.
          Used for rendering some pen types and influences the `width`.

  root_text:
    doc: |
      The page's typed text: a CRDT sequence of text items plus paragraph
      styles keyed by character id, a position and a width.
    seq:
      - id: block_id
        type: tagged_id(1)
      - id: content_tag
        type: tag(2, 0xc)
      - id: len_content
        type: u4
      - id: content
        size: len_content
        type: root_text_content
      - id: position_tag
        type: tag(3, 0xc)
      - id: len_position
        type: u4
      - id: position
        size: len_position
        type: root_text_position
      - id: width
        type: tagged_f4(4)
      - id: unknown_trailing
        size-eos: true

  root_text_content:
    seq:
      - id: items_tag
        type: tag(1, 0xc)
      - id: len_items
        type: u4
      - id: items
        size: len_items
        type: text_items_wrapper
      - id: styles_tag
        type: tag(2, 0xc)
      - id: len_styles
        type: u4
      - id: styles
        size: len_styles
        type: text_styles_wrapper
      - id: unknown_trailing
        size-eos: true

  text_items_wrapper:
    seq:
      - id: list_tag
        type: tag(1, 0xc)
      - id: len_list
        type: u4
      - id: list
        size: len_list
        type: text_items

  text_items:
    seq:
      - id: num_items
        type: varuint
      - id: items
        type: text_item
        repeat: expr
        repeat-expr: num_items.value

  text_item:
    doc: |
      A run of text. A string is split into many items as it is edited;
      order is given by `left_id`/`right_id`, not file order. Deleted runs
      have non-zero `deleted_length` and no `value`.
    seq:
      - id: tag
        type: tag(0, 0xc)
      - id: len_body
        type: u4
      - id: body
        size: len_body
        type: text_item_body

  text_item_body:
    seq:
      - id: item_id
        type: tagged_id(2)
      - id: left_id
        type: tagged_id(3)
      - id: right_id
        type: tagged_id(4)
      - id: deleted_length
        type: tagged_u4(5)
      - id: value
        type: tagged_string(6)
        if: not _io.eof

  text_styles_wrapper:
    seq:
      - id: list_tag
        type: tag(1, 0xc)
      - id: len_list
        type: u4
      - id: list
        size: len_list
        type: text_styles

  text_styles:
    seq:
      - id: num_styles
        type: varuint
      - id: styles
        type: text_style
        repeat: expr
        repeat-expr: num_styles.value

  text_style:
    doc: Paragraph style, applied from character `char_id`.
    seq:
      - id: char_id
        type: crdt_id
      - id: timestamp
        type: tagged_id(1)
      - id: value_tag
        type: tag(2, 0xc)
      - id: len_value
        type: u4
      - id: value
        size: len_value
        type: text_style_value

  text_style_value:
    seq:
      - id: style
        type: tagged_u1(1)
        doc: See enum `paragraph_style`.
    instances:
      style_enum:
        value: style.value
        enum: paragraph_style

  root_text_position:
    seq:
      - id: x
        type: f8
      - id: y
        type: f8

  header:
    seq:
      - id: magic
        contents: reMarkable .lines file, version=

      - id: version_string
        size: 1
        type: str
        doc: Version number, encoded as a single ASCII digit.

      - id: padding
        contents: '          '

    instances:
      version_number:
        value: version_string.to_i

  author_ids:
    doc: |
      Table of authors (devices/apps that have edited the page). The
      `author` byte of every `crdt_id` indexes this table. Differs between
      devices, so it can't be treated as constant.
    seq:
      - id: num_authors
        type: varuint
      - id: authors
        type: author_id
        repeat: expr
        repeat-expr: num_authors.value
      - id: unknown_trailing
        size-eos: true

  author_id:
    seq:
      - id: tag
        type: tag(0, 0xc)
      - id: len_body
        type: u4
      - id: body
        size: len_body
        type: author_id_body

  author_id_body:
    seq:
      - id: len_uuid
        type: varuint
      - id: uuid
        size: len_uuid.value
        doc: Author UUID, in little-endian (Microsoft GUID) byte order.
      - id: author_id
        type: u2
      - id: unknown_trailing
        size-eos: true

  migration_info:
    doc: |
      Migration marker. `is_device` and `unknown` are the two bytes that
      flip when a page is duplicated ("dupe_flip" in earlier versions of
      this spec).
    seq:
      - id: migration_id
        type: tagged_id(1)
      - id: is_device
        type: tagged_u1(2)
      - id: unknown
        type: tagged_u1(3)
        if: not _io.eof
      - id: unknown_trailing
        size-eos: true

  page_info:
    seq:
      - id: loads_count
        type: tagged_u4(1)
        doc: |
          Incremented each time the page is loaded/saved. Called
          "timestamp" in earlier versions of this spec.
      - id: merges_count
        type: tagged_u4(2)
      - id: text_chars_count
        type: tagged_u4(3)
      - id: text_lines_count
        type: tagged_u4(4)
      - id: type_folio_use_count
        type: tagged_u4(5)
        if: not _io.eof
      - id: unknown_trailing
        size-eos: true

  scene_info:
    seq:
      - id: current_layer
        type: lww(1, lww_kind::crdt_id)
        doc: The active layer, as a `scene_tree` node id.
      - id: background_visible
        type: lww(2, lww_kind::u1)
        if: not _io.eof
      - id: root_document_visible
        type: lww(3, lww_kind::u1)
        if: not _io.eof
      - id: unknown_trailing
        size-eos: true
        doc: Newer firmware appends further fields (e.g. paper size).

  image_table:
    doc: |
      Images referenced by `scene_image_item`s on this page. Image files
      are stored beside the page as `<doc id>/<page id>/<name>`, where
      `name` is `<uuid>.<ext>` (e.g. a JPEG straight from the camera
      roll). Note the image `key` is a different UUID from the one in
      `name`.
    seq:
      - id: list_tag
        type: tag(1, 0xc)
      - id: len_list
        type: u4
      - id: list
        size: len_list
        type: image_table_list
      - id: unknown_trailing
        size-eos: true

  image_table_list:
    seq:
      - id: num_images
        type: varuint
      - id: images
        type: image_entry
        repeat: expr
        repeat-expr: num_images.value

  image_entry:
    seq:
      - id: tag
        type: tag(0, 0xc)
      - id: len_body
        type: u4
      - id: body
        size: len_body
        type: image_entry_body

  image_entry_body:
    seq:
      - id: key
        size: 16
        doc: |
          Image key (untagged UUID, big-endian byte order), referenced by
          `image_value.image_ref`.
      - id: name
        type: lww(1, lww_kind::string)
        doc: File name of the image resource, `<uuid>.<ext>`.
      - id: crop
        type: lww(2, lww_kind::rect)
        doc: Optional source rectangle; probably a crop. Unset when observed.
      - id: unknown_trailing
        size-eos: true

  image_value:
    doc: |
      A placed image, drawn as a textured mesh.
    seq:
      - id: item_type
        type: u1
        valid: 7
      - id: image_ref
        type: lww(1, lww_kind::uuid)
        doc: Key of the image in the page's `image_table`.
      - id: bounds_timestamp
        type: tagged_id(2)
      - id: vertices_tag
        type: tag(3, 0xc)
      - id: len_vertices
        type: u4
      - id: vertices
        size: len_vertices
        type: f4_list
        doc: |
          Flat list of `x, y, u, v` per vertex: page coordinates (same
          origin as stroke points) and texture coordinates. Usually four
          vertices with UVs (0,0) (1,0) (1,1) (0,1).
      - id: indices_tag
        type: tag(4, 0xc)
      - id: len_indices
        type: u4
      - id: indices
        size: len_indices
        type: u4_list
        doc: Triangle indices into `vertices`; usually 0,1,2, 2,3,0.
      - id: move_id
        type: tagged_id(5)
        if: not _io.eof
      - id: unknown_trailing
        size-eos: true

  f4_list:
    seq:
      - id: num_values
        type: varuint
      - id: values
        type: f4
        repeat: expr
        repeat-expr: num_values.value

  u4_list:
    seq:
      - id: num_values
        type: varuint
      - id: values
        type: u4
        repeat: expr
        repeat-expr: num_values.value
