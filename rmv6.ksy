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
  - id: frontmatter
    type: rm_frontmatter
    doc: |
      Header and unknown boilerplate at the start of the file. The primary
      information currently extracted from this section is the format version
      (which should always be 6).

  - id: blocks
    type: block
    repeat: eos
    doc: |
      Blocks contain the primary data structures of the file, and are in
      size-type-value format. See the `block_flags` enum and `block` type.

enums:
  block_flags:
    0x1010100:
      id: layer_def
      doc: |
        Initial enumeration of layers present, including the text layer.
        There is one block per layer. See `rm_layer_definition`.
    0x2020100: 
      id: layer_names
      doc: |
        Names given to each layer, if present. Also other related info that
        has not yet been reverse-engineered. One block per layer. See
        `rm_layer_name`.
    0x7010100:
      id: text_def
      doc: |
        The definition of the text on the page. At most one block per page.
        See `rm_text_definition`.
    0x4010100: 
      id: layer_info
      doc: |
        Additional information about layers. Not yet reverse-engineered.
        One block per layer. See `rm_layer_info`.
    0x5020200: 
      id: line_def
      doc: |
        Line definition, enumerating what is drawn on the screen. See
        `rm_line`.
    
  formatting_types:
    0x01000000: 
      id: bold_start
      doc: Denotes beginning of bold text. `$ 01 00 00 00`.
    0x02000000: 
      id: bold_end
      doc: Denotes end of bold text. `$ 02 00 00 00`.
    0x03000000: 
      id: italic_start
      doc: Denotes beginning of italic text. `$ 04 00 00 00`.
    0x04000000: 
      id: italic_end
      doc: Denotes end of italic text. `$ 04 00 00 00`.
    
    
types:
  
  empty: {}
  
  block:
    doc: |
      A block of data, storing some major structure of the format.

      Blocks follow a size-type-value scheme, where a size (`len_body`)
      describes the byte length of the block's held value (`body`) and
      the value's type (`flag`, see enum `block_flags`).

    seq:
      - id: len_body
        type: u4
        doc: Byte count for block's main body.

      - id: flag
        type: u4le
        enum: block_flags
        doc: |
          Flag indicating the type of value stored in block body. See
          enum `block_flags`.

      - id: body
        size: len_body
        type:
          switch-on: flag
          cases:
            'block_flags::layer_def': rm_layer_definition
            'block_flags::layer_names': rm_layer_name
            'block_flags::text_def': rm_text_definition
            'block_flags::layer_info': rm_layer_info
            'block_flags::line_def': rm_line
            _: empty
        doc: Contains inner value of block.

  rm_layer_definition:
    doc: Defines each layer's id.

    seq:
      - id: magic_0 
        contents: [0x1f]

      - id: layer_id
        #size: 2
        terminator: 0x2f
        consume: false
        doc: |
          Identifier for this layer that appears in other structures in reference
          to this layer. There are some data types (defined below) that have 
          fields with layer ids that appear to be incremented by 1 or 2. Eg, for 
          a `layer_id` of `00 0b` a field may have `00 0c` or `00 0d`. What this 
          means is still unclear.

      - id: magic_1
        contents: [0x2f]

      - id: unknown_00
        #size: 4
        terminator: 0x4c
        consume: false

      - id: magic_2
        contents: [0x4c]

      - id: len_unknown
        type: u4
        doc: |
          This byte count refers to the remainder of the block, but it is
          unclear what is present in that space.

      - id: magic_3
        contents: [0x1f]

      - size: 1
        repeat: eos

  rm_layer_name:
    doc: |
      The primary purpose of this block is to match textual names to
      their associated layer ids. There is additional data here as well,
      but it's not clear what it means. Also, once in a while there is
      even more data at the end of this block that might be related to
      either the bold/italic formatting, or the forced moving of drawn
      lines when text is added.

    seq:
      - id: magic_0
        contents: [0x1f]

      - id: id
        #size: 2
        terminator: 0x2c
        consume: false
        doc: The layer's identifier.

      - id: magic_1
        contents: [0x2c]

      - id: len_rest0
        type: u4
        doc: Byte length from here to magic_5 (3c)

      - id: magic_2
        contents: [0x1f]

      - size: 2
        doc: | 
          This appears to be id plus 1. An id of `01 11` becomes `01 12`
          here for some reason

      - id: magic_3
        contents: [0x2c]

      - id: len_rest1
        type: u4
        doc: Byte length from here to magic_5 (3c)

      - id: len_name
        type: u1
        doc: Single byte length of the layer name as a string.

      - id: magic_4
        contents: [0x01]
        doc: 01 byte marks the start of a string.

      - id: name
        type: str
        size: len_name

      - id: magic_5
        contents: [0x3c]

      - id: len_unknown
        type: u4
        doc: |
          This byte count refers to the remainder of the block, but it is
          unclear what is present in that space.

      - id: magic_6
        contents: [0x1f]

      - size: 2

      - id: magic_7
        contents: [0x21, 0x01]

      # there's more below here sometimes, related to when there's italic/bold?
      # how to deal with that? Does it even matter? Who knows! (It probably does)
    
  rm_text_definition:
    doc: |
      The text definition block defines the text data on this page. Each page
      will only have a single text definition block, which includes sub objects
      for each of the text blocks and formatting flags necessary.

      Sub objects within a text block include `rm_text_single` and
      `rm_text_backmatter`.

    seq:
      - id: magic_0
        contents: [0x1f]

      - size: 2

      - id: magic_1
        contents: [0x2c]

      - id: len_text0
        type: u4

      - id: magic_2
        contents: [0x1c]

      - id: len_text1
        type: u4

      - id: magic_3
        contents: [0x1c]

      - id: len_text2
        type: u4

      - id: num_text_entries
        type: u1

      - id: texts
        type: rm_text_single
        repeat: expr
        repeat-expr: num_text_entries
        doc: |
          Text entry sub objects repeat and are described both with a count
          (`num_text_entries`) and a total size (`len_text2`, minus the 
          count's byte).

      - id: magic_4
        contents: [0x2c]
          
      - id: len_backmatter
        type: u4

      - id: backmatter
        type: rm_text_backmatter
        size: len_backmatter
        doc: |
          Additional structured data associated with the text that is not
          the text itself.

      - id: magic_5
        contents: [0x3c]

      - id: len_rest
        type: u4
        doc: Byte count for the next section. not quite to the end of block?

      - size: 1
        repeat: expr
        repeat-expr: len_rest

      - size: 1
        repeat: eos

  rm_text_backmatter:
    doc: |
      Wrapper object to handle repeating backmatter structures. See
      `rm_text_backmatter_piece` and `rm_text_definition`.

    seq:
      - id: magic_0
        contents: [0x1c]

      - id: len_rest
        type: u4
        doc: Byte count to end of backmatter section (end of `pieces`)

      - size: 1
        doc: Possibly magic
  
      - id: pieces
        type: rm_text_backmatter_piece
        repeat: eos

  rm_text_backmatter_piece:
    seq:
      - size: 2

      - id: magic_0
        contents: [0x1f]

      - id: unknown_00
        #size: 2
        terminator: 0x2c
        consume: false

      - id: magic_1
        contents: [0x2c]

      - id: len_unknown
        type: u4

      - size: 2

  rm_text_single:
    doc: |
      This section encodes a single chunk of text, with some associated
      information about positioning and identity. A single string of text
      may be broken up into many of these chunks depending on how many
      times the text was edited.

    seq:
      - id: magic_0
        contents: [0x0c]

      - id: len_text0
        type: u4
        doc: Byte count to end of this single text object

      - id: magic_1
        contents: [0x2f]

      - id: chunk_id
        terminator: 0x3f
        consume: false
        doc: |
          It's not entirely clear how this works yet, but this is either
          an identifier for this text chunk, or its address in the text space,
          or both. Two additional similar fields appear next, and are often
          used to (possibly) link, point, or refer to other chunks or locations
          in the text. Of the three total "chunk_id" fields identified here,
          this one is the most understood. It is never the same, and the first
          chunk of the file always has this set to 00 14 or 00 15, with the 
          other two fields both set to 0.

      - id: magic_2
        contents: [0x3f]

      - id: other_chunk_id_1
        terminator: 0x4f
        consume: false
        doc: See `chunk_id`

      - id: magic_3
        contents: [0x4f]

      - id: other_chunk_id_2
        terminator: 0x54
        consume: false
        doc: See `chunk_id`

      - id: magic_4
        contents: [0x54]
        
      - id: done_flag
        type: u4
        doc: | 
          When set to 0, no further information is stored in this chunk.
          However, this value is sometimes something besides 0 or 1. I have
          seen 2, 3, 5, etc. Unclear if this is truly a binary flag or if
          other information is stored in it.
        
      - id: magic_5
        contents: [0x6c]
        if: done_flag==0

      - id: len_text1
        type: u4
        if: done_flag==0

      - id: len_text_string
        type: u1
        if: done_flag==0

      - id: magic_6
        contents: [0x01]
        if: done_flag==0

      - id: text_string
        type: str
        size: len_text_string
        if: done_flag==0
        doc: This field is the actual text itself, as UTF-8.

      - id: magic_dollar
        contents: [0x24]
        if: len_text1 - len_text_string - 2 == 5
        doc: If present, it is a literal "$" and preceeds `dollar_value`.

      - id: dollar_value
        type: u4
        enum: formatting_types
        if: len_text1 - len_text_string - 2 == 5
        doc: |
          If present, this encodes the beginning or end of a formatted
          region of the text (eg, bold or italic). See the `formatting_types`
          enum for details.
    
  rm_layer_info:
    doc: |
      This is the final of the three types of blocks related to layers.
      Most of the fields appear to be in the `layer_id` style (see 
      `rm_layer_definition`) and may include the aforementioned incremented
      ids. I am not sure of the function of this block at the moment.

    seq:
    - id: magic_0
      contents: [0x1f]

    - id: id_field_1
      type: u2

    - id: magic_2f
      contents: [0x2f]

    - id: id_field_2
      #type: u2
      terminator: 0x3f
      consume: false


    - id: magic_3f
      contents: [0x3f]

    - id: id_field_3
      #type: u2
      terminator: 0x4f
      consume: false

    - id: magic_4f
      contents: [0x4f]

    - id: id_field_4
      type: u2

    - id: magic_54
      contents: [0x54]

    - id: done_flag
      type: u4

    - id: magic_6c
      contents: [0x6c]
      if: done_flag == 0

    - id: len_always_4 # was 5 when a bunch of the ids were extra long
      size: 4
      #contents: [0x04, 0x00, 0x00, 0x00]
      if: done_flag == 0
      doc: This is definitely a byte count, but is always 4.

    - id: magic
      contents: [0x02, 0x2f]
      if: done_flag == 0

    - id: layer_id
      type: u2
      if: done_flag == 0
      doc: |
        If present, this is appears to be the actual identifier of the layer
        in question.
      
  rm_line:
    doc: |
      A "line" is typically the result of a single stroke of the tablet's
      stylus, and represents some line segment on the page. Lines include
      information about the pen type and color, and then are defined as a
      (long) array of individual points (`rm_point`). Here it is broken up
      into the `header` section, which includes the pen information and
      point count, and the `point_array` section, which is just an array
      of point structs.

      Of the types in this spec, the line and point structs are the ones 
      most similar to previous versions of the ReMarkable file format.

    seq:
      - id: header
        type: rm_line_header

      - id: point_array
        type: rm_point
        repeat: expr
        repeat-expr: header.len_point_array / 14 # each point is 14 bytes so...
        if: header.done_flag == 0
        doc: |
          Each point struct is 14 bytes, so there are len_point_array / 14
          point structs. See `rm_line_header` and `rm_point`.

      - id: magic_end
        contents: [0x6f, 0x00, 0x01]
        if: header.done_flag == 0
        doc: |
          If this block is nontrivial, `done_flag` will be 0 and `point_array`
          will be terminated with this 3-byte sequence.
  
  rm_line_header:
    doc: |
      The header information of the `rm_line`, including identity and pen info.

    seq:
    - id: magic_0
      contents: [0x1f]

    - id: layer_id
      #type: u2
      terminator: 0x2f
      consume: false
      doc: Id of the layer this line is associated with. See `rm_layer_definition`.

    - id: magic_1
      contents: [0x2f]

    - id: line_id
      #type: u2
      terminator: 0x3f
      consume: false
      doc: A unique identifier for this line.

    - id: magic_2
      contents: [0x3f]

    - id: last_line_id
      #type: u2
      terminator: 0x4f
      consume: false
      doc: The `line_id` of the previously-drawn line.

    - id: magic_3
      contents: [0x4f]

    - id: id_field_0
      type: u2
      doc: This field is sometimes used and appears to be a line id.

    - id: magic_4
      contents: [0x54]

    - id: done_flag
      type: u4
      doc: |
        If this is 0, then the below information about pen, color, and
        the point array is included. This is likely used to distinguish
        between instantiated and assigned line structs.

    - id: magic_5
      contents: [0x6c]
      if: done_flag == 0

    - id: len_block_0
      type: u4
      if: done_flag == 0
      doc: Byte count from here to the end of the line block.

    - id: magic_6
      contents: [0x03, 0x14]
      if: done_flag == 0

    - id: pen_type
      type: u4
      if: done_flag == 0
      doc: TODO make this an enum

    - id: magic_7
      contents: [0x24]
      if: done_flag == 0

    - id: color
      type: u4
      if: done_flag == 0
      doc: TODO make this an enum

    - id: magic_8
      contents: [0x38, 0x00, 0x00, 0x00, 0x00]
      if: done_flag == 0

    - id: brush_size
      type: f4
      if: done_flag == 0
      doc: TODO make this an enum

    - id: magic_9
      contents: [0x44, 0x00, 0x00, 0x00, 0x00]
      if: done_flag == 0

    - id: magic_10
      contents: [0x5c]
      if: done_flag == 0

    - id: len_point_array
      type: u4
      if: done_flag == 0
        
  rm_point:
    doc: |
      A struct representing a single point/dot on the screen, many of which
      make up a single line.

    seq:
    - id: x
      type: f4
      doc: X coordinate of the point. Origin is in the center of the page.

    - id: y
      type: f4
      doc: Y coordinate of the point. Origin is at the top of the page.

    - id: speed
      type: u1
      doc: |
        Speed the stylus was moving when this point was drawn. Used for
        rendering some pen types and influences the `width`.

    - id: pad0
      type: u1

    - id: width
      type: u1
      doc: Rendered width of the point on the screen.

    - id: pad1
      type: u1

    - id: direction
      type: u1
      doc: |
        Direction the stylus was moving when this point was drawn. "Direction"
        here is encoded as an angle mapped onto a single byte. For example,
        a value of 0 correlates to 0 degrees and a value of 255 correlates to
        360 degrees (or just under 360, rather). 0 degrees points to the right
        on the page and increases clockwise. So 90 degrees (or a value of 
        255/4 = ~64) indicates moving downward.

    - id: pressure
      type: u1
      doc: |
        A value representing how hard the stylus was pressing on the screen.
        Used for rendering some pen types and influences the `width`.


  rm_frontmatter:
    doc: |
      The frontmatter at the top of the file. Most of this is not understood,
      but most of it also remains constant across files.

    seq:
      - id: header
        size: 43
        type: rm_frontmatter_header

      - id: magic_1
        contents: [
          0x19, 0x00, 0x00, 0x00, 0x00,
          
          0x01, 0x01, 0x09, 0x01, 0x0c, 0x13, 0x00, 0x00,
          
          0x00, 0x10, 0xeb, 0x2f, 0xac, 0x80, 0xfb, 0x2e,
          
          0x59, 0x8d, 0xa7, 0x14, 0xdf, 0x4e, 0xc5, 0x65,
          
          0x0b, 0x8e, 0x01, 0x00, 0x07, 0x00, 0x00, 0x00,
          
          0x00, 0x01, 0x01, 0x00, 0x1f, 0x01, 0x01, 0x21]
      - id: dupe_flip_1 # the dupe flips were 1 and 0 but became 0 and 1 when page copied
        type: u1      
      - id: magic_2
        contents: [0x31]
      - id: dupe_flip_2
        type: u1
      - id: magic_3
        contents: [
          0x19, 0x00, 0x00, 0x00, 0x00,
          
          0x00, 0x01, 0x0a,
          ]
      - id: x4_chunks
        type: rm_x4_chunks
      - id: magic_4
        contents: [0x1f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x0d, 0x1c, 0x06, 0x00, 0x00, 0x00, 0x1f]
      - id: unknown_2
        type: u2
      - id: magic_5
        contents: [0x2f]
      - id: active_layer
        type: u2
      - id: magic_6
        contents: [0x2c, 0x05, 0x00, 0x00, 0x00, 0x1f, 0x00, 0x00, 0x21, 0x01]
      - id: pre_magic
        contents: [0x3c, 0x05, 0x00, 0x00, 0x00, 0x1f, 0x00, 0x00, 0x21, 0x01]


  rm_frontmatter_header:
    seq:
      - id: magic_text
        size: 32
        contents: reMarkable .lines file, version=

      - id: version_string
        size: 1
        type: str
        doc: Version number, but encoded as a single UTF-8 character.

      - id: ten_spaces
        contents: [0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20]

    instances:
      version_number:
        value: version_string.to_i

  rm_x4_chunks:
    doc: |
      This is a section of the frontmatter that encodes file-level information,
      but it's not all understood.

    seq:
      - id: magic_0
        contents: [0x14]

      - id: timestamp
        type: u4
        doc: |
          Starts at 1, and increments when the file is updated/saved.
          This has been named "timestamp" because it seems to correlate to
          the `timestamp` field in the .contents file associated with this
          notebook.

      - id: magic_1
        contents: [0x24]

      - type: u4

      - id: magic_3
        contents: [0x34]

      - type: u4

      - id: magic_4
        contents: [0x44]

      - type: u4

      - id: magic_5
        contents: [0x54]

      - type: u4
