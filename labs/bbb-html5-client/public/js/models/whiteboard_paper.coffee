define [
  'jquery',
  'underscore',
  'backbone',
  'raphael',
  'globals',
  'cs!utils'
], ($, _, Backbone, Raphael, globals, Utils) ->

  # TODO: text, ellipse, line, rect and cursor could be models

  # TODO: temporary solution
  PRESENTATION_SERVER = window.location.protocol + "//" + window.location.host
  PRESENTATION_SERVER = PRESENTATION_SERVER.replace(/:\d+/, "/") # remove :port

  MAX_PATHS_IN_SEQUENCE = 30

  # "Paper" which is the Raphael term for the entire SVG object on the webpage.
  # This class deals with this SVG component only.
  WhiteboardPaperModel = Backbone.Model.extend

    # Container must be a DOM element
    initialize: (@container, @textbox) ->
      @gw = null # TODO: description
      @gh = null # TODO: description
      # x-offset from top left corner as percentage of original width of paper
      @cx = null
      # y-offset from top left corner as percentage of original height of paper
      @cy = null
      # sw slide width as percentage of original width of paper
      @sw = null
      # sh slide height as a percentage of original height of paper
      @sh = null

      @panX = null
      @panY = null
      @lineX = null
      @lineY = null
      @ellipseX = null
      @ellipseY = null
      @textX = null
      @textY = null

      # TODO: could be local variables or defined with better names
      @cx2 = null
      @cy2 = null

      @cursor = null
      @cursorRadius = 4
      @slides = null
      @currentUrl = null
      @fitToPage = true
      @currentShapes = null
      @currentLine = null
      @currentRect = null
      @currentEllipse = null
      @currentText = null
      @zoomLevel = 1
      @shiftPressed = false
      @currentPathCount = 0

      $(window).on "resize.whiteboard_paper", _.bind(@_onWindowResize, @)
      $(document).on "keydown.whiteboard_paper", _.bind(@_onKeyDown, @)
      $(document).on "keyup.whiteboard_paper", _.bind(@_onKeyUp, @)

      @_updateContainerDimensions()

    # Override the close() to unbind events.
    unbindEvents: ->
      $(window).off "resize.whiteboard_paper"
      $(document).off "keydown.whiteboard_paper"
      $(document).off "keyup.whiteboard_paper"
      # TODO: other events are being used in the code and should be off() here

    # Initializes the paper in the page.
    # Can't do these things in initialize() because by then some elements
    # are not yet created in the page.
    create: ->
      # paper is embedded within the div#slide of the page.
      @raphaelObj ?= Raphael(@container, @gw, @gh)
      @raphaelObj.canvas.setAttribute "preserveAspectRatio", "xMinYMin slice"
      @cursor = @raphaelObj.circle(0, 0, @cursorRadius)
      @cursor.attr "fill", "red"

      $(@cursor.node).on "mousewheel", _.bind(@_zoomSlide, @)
      if @slides
        @rebuild()
      else
        @slides = {} # if previously loaded
      unless navigator.userAgent.indexOf("Firefox") is -1
        @raphaelObj.renderfix()

    # Re-add the images to the paper that are found
    # in the slides array (an object of urls and dimensions).
    rebuild: ->
      @currentUrl = null
      for url of @slides
        if @slides.hasOwnProperty(url)
          @addImageToPaper url, @slides[url].w, @slides[url].h

    # Add an image to the paper.
    # @param {string} url the URL of the image to add to the paper
    # @param {number} width   the width of the image (in pixels)
    # @param {number} height   the height of the image (in pixels)
    # @return {Raphael.image} the image object added to the whiteboard
    addImageToPaper: (url, width, height) ->
      @_updateContainerDimensions()

      # TODO: temporary adaptation for iPads
      width = 670
      height = 515

      console.log "adding image to paper", url, width, height
      if @fitToPage
        # solve for the ratio of what length is going to fit more than the other
        max = Math.max(width / @containerWidth, height / @containerHeight)
        # fit it all in appropriately
        # TODO: temporary solution
        url = PRESENTATION_SERVER + url unless url.match(/http[s]?:/)
        img = @raphaelObj.image(url, @cx = 0, @cy = 0, @gw = width, @gh = height)

        # update the global variables we will need to use
        @sw = width / max
        @sh = height / max
        # sw_orig = sw
        # sh_orig = sh
      else
        # fit to width
        # assume it will fit width ways
        wr = width / @containerWidth
        img = @raphaelObj.image(url, @cx = 0, @cy = 0, width / wr, height / wr)
        @sw = width / wr
        @sh = height / wr
        # sw_orig = sw
        # sh_orig = sh
        @gw = @sw
        @gh = @sh
      @slides[url] =
        id: img.id
        w: width
        h: height

      unless @currentUrl
        img.toBack()
        @currentUrl = url
      else if @currentUrl is url
        img.toBack()
      else
        img.hide()
      $(@container).on "mousemove", _.bind(@_onCursorMove, @)
      $(@container).on "mousewheel", _.bind(@_zoomSlide, @)
      # TODO $(img.node).bind "mousewheel", zoomSlide
      @trigger('paper:image:added', img)

      # TODO: other places might also required an update in these dimensions
      @_updateContainerDimensions()

      img

    # Removes all the images from the Raphael paper.
    removeAllImagesFromPaper: ->
      for url of @slides
        if @slides.hasOwnProperty(url)
          @raphaelObj.getById(@slides[url].id).remove()
          @trigger('paper:image:removed', @slides[url].id)
      @slides = {}
      @currentUrl = null

    # Shows an image from the paper.
    # The url must be in the slides array.
    # @param  {string} url the url of the image (must be in slides array)
    showImageFromPaper: (url) ->
      unless @currentUrl is url
        # TODO: temporary solution
        url = PRESENTATION_SERVER + url unless url.match(/http[s]?:/)
        @_hideImageFromPaper @currentUrl
        next = @_getImageFromPaper(url)
        if next
          next.show()
          next.toFront()
          @currentShapes.forEach (element) ->
            element.toFront()
          @_bringCursorToFront()
        @currentUrl = url

    # Updates the paper from the server values.
    # @param  {number} cx_ the x-offset value as a percentage of the original width
    # @param  {number} cy_ the y-offset value as a percentage of the original height
    # @param  {number} sw_ the slide width value as a percentage of the original width
    # @param  {number} sh_ the slide height value as a percentage of the original height
    # TODO: not tested yet
    updatePaperFromServer: (cx_, cy_, sw_, sh_) ->
      # if updating the slide size (zooming!)
      if sw_ and sh_
        @raphaelObj.setViewBox cx_ * @gw, cy_ * @gh, sw_ * @gw, sh_ * @gh
        @sw = @gw / sw_
        @sh = @gh / sh_
      # just panning, so use old slide size values
      else
        @raphaelObj.setViewBox cx_ * @gw, cy_ * @gh, @raphaelObj._viewBox[2], @raphaelObj._viewBox[3]

      # update corners
      @cx = cx_ * @sw
      @cy = cy_ * @sh
      # update position of svg object in the window
      sx = (@containerWidth - @gw) / 2
      sy = (@containerHeight - @gh) / 2
      sy = 0  if sy < 0
      @raphaelObj.canvas.style.left = sx + "px"
      @raphaelObj.canvas.style.top = sy + "px"
      @raphaelObj.setSize @gw - 2, @gh - 2

      # update zoom level and cursor position
      z = @raphaelObj._viewBox[2] / @gw
      @cursor.attr r: dcr * z
      @zoomLevel = z

      # force the slice attribute despite Raphael changing it
      @raphaelObj.canvas.setAttribute "preserveAspectRatio", "xMinYMin slice"

    # Switches the tool and thus the functions that get
    # called when certain events are fired from Raphael.
    # @param  {string} tool the tool to turn on
    # @return {undefined}
    setCurrentTool: (tool) ->
      @currentTool = tool
      console.log "setting current tool to", tool
      switch tool
        when "line"
          @cursor.undrag()
          @cursor.drag _.bind(@_lineDragging, @),
            _.bind(@_lineDragStart, @), _.bind(@_lineDragStop, @)
        when "rect"
          @cursor.undrag()
          @cursor.drag _.bind(@_rectDragging, @),
            _.bind(@_rectDragStart, @), _.bind(@_rectDragStop, @)
        when "panzoom"
          @cursor.undrag()
          @cursor.drag _.bind(@_panDragging, @),
            _.bind(@_panGo, @), _.bind(@_panStop, @)
        when "ellipse"
          @cursor.undrag()
          @cursor.drag _.bind(@_ellipseDragging, @),
            _.bind(@_ellipseDragStart, @), _.bind(@_ellipseDragStop, @)
        when "text"
          @cursor.undrag()
          @cursor.drag _.bind(@_rectDragging, @),
            _.bind(@_textStart, @), _.bind(@_textStop, @)
        else
          console.log "ERROR: Cannot set invalid tool:", tool

    # Sets the fit to page.
    # @param {boolean} value If true fit to page. If false fit to width.
    # TODO: not really working as it should be
    setFitToPage: (value) ->
      @fitToPage = value
      temp = @slides
      @removeAllImagesFromPaper()
      @slides = temp
      # re-add all the images as they should fit differently
      @rebuild()
      # set to default zoom level
      globals.connection.emitPaperUpdate 0, 0, 1, 1
      # get the shapes to reprocess
      globals.connection.emitAllShapes()

    # Socket response - Update zoom variables and viewbox
    # @param {number} d the delta value from the scroll event
    # @return {undefined}
    setZoom: (d) ->
      step = 0.05 # step size
      if d < 0
        @zoomLevel += step # zooming out
      else
        @zoomLevel -= step # zooming in
      x = @cx / @sw
      y = @cy / @sh
      # cannot zoom out further than 100%
      z = (if @zoomLevel > 1 then 1 else @zoomLevel)
      # cannot zoom in further than 400% (1/4)
      z = (if z < 0.25 then 0.25 else z)
      # cannot zoom to make corner less than (x,y) = (0,0)
      x = (if x < 0 then 0 else x)
      y = (if y < 0 then 0 else y)
      # cannot view more than the bottom corners
      zz = 1 - z
      x = (if x > zz then zz else x)
      y = (if y > zz then zz else y)
      globals.connection.emitPaperUpdate x, y, z, z # send update to all clients

    stopPanning: ->
      # nothing to do

    # The server has said the text is finished,
    # so set it to null for the next text object
    textDone: ->
      if @currentText?
        @currentText = null
        @currentRect.hide() if @currentRect?

    # Draws an array of shapes to the paper.
    # @param  {array} shapes the array of shapes to draw
    drawListOfShapes: (shapes) ->
      @currentShapes = @raphaelObj.set()
      for shape in shapes
        data = JSON.parse(shape.data)
        switch shape.shape
          when "path"
            @_drawLine.apply @, data
          when "rect"
            @_drawRect.apply @, data
          when "ellipse"
            @_drawEllipse.apply @, data
          when "text"
            @_drawText.apply @, data

      # make sure the cursor is still on top
      @_bringCursorToFront()

    # Updated a shape `shape` with the data in `data`.
    updateShape: (shape, data) ->
      switch shape
        when "line"
          @_updateLine.apply @, data
        when "rect"
          @_updateRect.apply @, data
        when "ellipse"
          @_updateEllipse.apply @, data
        when "text"
          @_updateText.apply @, data
        else
          console.log "shape not recognized at updateShape", shape

    # Make a shape `shape` with the data in `data`.
    makeShape: (shape, data) ->
      switch shape
        when "line"
          @_makeLine.apply @, data
        when "rect"
          @_makeRect.apply @, data
        when "ellipse"
          @_makeEllipse.apply @, data
        else
          console.log "shape not recognized at makeShape", shape

    # Update the cursor position on screen
    # @param  {number} x the x value of the cursor as a percentage of the width
    # @param  {number} y the y value of the cursor as a percentage of the height
    moveCursor: (x, y) ->
      @cursor.attr
        cx: x * @gw
        cy: y * @gh

    # Update the dimensions of the container.
    _updateContainerDimensions: ->
      $container = $(@container)
      @containerWidth = $container.innerWidth()
      @containerHeight = $container.innerHeight()
      @containerOffsetLeft = $container.offset().left
      @containerOffsetTop = $container.offset().top

    # Retrieves an image element from the paper.
    # The url must be in the slides array.
    # @param  {string} url        the url of the image (must be in slides array)
    # @return {Raphael.image}     return the image or null if not found
    _getImageFromPaper: (url) ->
      if @slides[url]
        id = @slides[url].id
        return @raphaelObj.getById(id) if id?
      null

    # Hides an image from the paper given the URL.
    # The url must be in the slides array.
    # @param  {string} url the url of the image (must be in slides array)
    _hideImageFromPaper: (url) ->
      img = @_getImageFromPaper(url)
      img.hide() if img?

    # Clear all shapes from this paper.
    _clearShapes: ->
      console.log "clearing shapes", @currentShapes
      if @currentShapes?
        @currentShapes.forEach (element) ->
          element.remove()

    # Puts the cursor on top so it doesn't get hidden behind any objects.
    _bringCursorToFront: ->
      @cursor.toFront()

    # Drawing a line from the list o
    # @param  {string} path      height of the shape as a percentage of the original height
    # @param  {string} colour    the colour of the shape to be drawn
    # @param  {number} thickness the thickness of the line to be drawn
    _drawLine: (path, colour, thickness) ->
      line = @raphaelObj.path(Utils.stringToScaledPath(path, @gw, @gh))
      line.attr
        stroke: colour
        "stroke-width": thickness
      @currentShapes.push line

    # Draw a rectangle on the paper
    # @param  {number} x         the x value of the object as a percentage of the original width
    # @param  {number} y         the y value of the object as a percentage of the original height
    # @param  {number} w         width of the shape as a percentage of the original width
    # @param  {number} h         height of the shape as a percentage of the original height
    # @param  {string} colour    the colour of the object
    # @param  {number} thickness the thickness of the object's line(s)
    # TODO: not tested yet
    _drawRect: (x, y, w, h, colour, thickness) ->
      r = @raphaelObj.rect(x * @gw, y * @gh, w * @gw, h * @gh)
      if colour
        r.attr
          stroke: colour
          "stroke-width": thickness
      @currentShapes.push r

    # Draw an ellipse on the whiteboard
    # @param  {[type]} cx        the x value of the center as a percentage of the original width
    # @param  {[type]} cy        the y value of the center as a percentage of the original height
    # @param  {[type]} rx        the radius-x of the ellipse as a percentage of the original width
    # @param  {[type]} ry        the radius-y of the ellipse as a percentage of the original height
    # @param  {string} colour    the colour of the object
    # @param  {number} thickness the thickness of the object's line(s)
    # TODO: not tested yet
    _drawEllipse: (cx, cy, rx, ry, colour, thickness) ->
      elip = @raphaelObj.ellipse(cx * @gw, cy * @gh, rx * @gw, ry * @gh)
      if colour
        elip.attr
          stroke: colour
          "stroke-width": thickness
      @currentShapes.push elip

    # Drawing the text on the whiteboard from object
    # @param  {string} t        the text of the text object
    # @param  {number} x        the x value of the object as a percentage of the original width
    # @param  {number} y        the y value of the object as a percentage of the original height
    # @param  {number} w        the width of the text box as a percentage of the original width
    # @param  {number} spacing  the spacing between the letters
    # @param  {string} colour   the colour of the text
    # @param  {string} font     the font family of the text
    # @param  {number} fontsize the size of the font (in PIXELS)
    # TODO: not tested yet
    _drawText: (t, x, y, w, spacing, colour, font, fontsize) ->
      x = x * @gw
      y = y * @gh
      txt = @raphaelObj.text(x, y, "").attr(
        fill: colour
        "font-family": font
        "font-size": fontsize
      )
      txt.node.style["text-anchor"] = "start" # force left align
      txt.node.style["textAnchor"] = "start"  # for firefox, 'cause they like to be different
      dy = textFlow(t, txt.node, w, x, spacing, false)
      @currentShapes.push txt

    # Make a line on the whiteboard that could be updated shortly after
    # @param  {number} x         the x value of the line start point as a percentage of the original width
    # @param  {number} y         the y value of the line start point as a percentage of the original height
    # @param  {string} colour    the colour of the shape to be drawn
    # @param  {number} thickness the thickness of the line to be drawn
    # TODO: not tested yet
    _makeLine: (x, y, colour, thickness) ->
      x *= @gw
      y *= @gh
      @currentLine = @raphaelObj.path("M" + x + " " + y + "L" + x + " " + y)
      if colour
        @currentLine.attr
          stroke: colour
          "stroke-width": thickness
      @currentShapes.push @currentLine

    # Socket response - Make rectangle on canvas
    # @param  {number} x         the x value of the object as a percentage of the original width
    # @param  {number} y         the y value of the object as a percentage of the original height
    # @param  {string} colour    the colour of the object
    # @param  {number} thickness the thickness of the object's line(s)
    # TODO: not tested yet
    _makeRect: (x, y, colour, thickness) ->
      @currentRect = @raphaelObj.rect(x * @gw, y * @gh, 0, 0)
      if colour
        @currentRect.attr
          stroke: colour
          "stroke-width": thickness
      @currentShapes.push @currentRect

    # Make an ellipse on the whiteboard
    # @param  {[type]} cx        the x value of the center as a percentage of the original width
    # @param  {[type]} cy        the y value of the center as a percentage of the original height
    # @param  {string} colour    the colour of the object
    # @param  {number} thickness the thickness of the object's line(s)
    # TODO: not tested yet
    _makeEllipse: (cx, cy, colour, thickness) ->
      @currentEllipse = @raphaelObj.ellipse(cx * @gw, cy * @gh, 0, 0)
      if colour
        @currentEllipse.attr
          stroke: colour
          "stroke-width": thickness
      @currentShapes.push @currentEllipse

    # Updating drawing the line
    # @param  {number} x2  the next x point to be added to the line as a percentage of the original width
    # @param  {number} y2  the next y point to be added to the line as a percentage of the original height
    # @param  {boolean} add true if the line should be added to the current line, false if it should replace the last point
    # TODO: not tested yet
    _updateLine: (x2, y2, add) ->
      if @currentLine?
        x2 *= @gw
        y2 *= @gh

        # if adding to the line
        if add
          @currentLine.attr path: (@currentLine.attrs.path + "L" + x2 + " " + y2)

        # if simply updating the last portion (for drawing a straight line)
        else
          @currentLine.attrs.path.pop()
          path = @currentLine.attrs.path.join(" ")
          @currentLine.attr path: (path + "L" + x2 + " " + y2)

    # Socket response - Update rectangle drawn
    # @param  {number} x1 the x value of the object as a percentage of the original width
    # @param  {number} y1 the y value of the object as a percentage of the original height
    # @param  {number} w  width of the shape as a percentage of the original width
    # @param  {number} h  height of the shape as a percentage of the original height
    # TODO: not tested yet
    _updateRect: (x1, y1, w, h) ->
      if @currentRect?
        @currentRect.attr
          x: (x1) * @gw
          y: (y1) * @gh
          width: w * @gw
          height: h * @gh

    # Socket response - Update rectangle drawn
    # @param  {number} x the x value of the object as a percentage of the original width
    # @param  {number} y the y value of the object as a percentage of the original height
    # @param  {number} w width of the shape as a percentage of the original width
    # @param  {number} h height of the shape as a percentage of the original height
    # TODO: not tested yet
    _updateEllipse: (x, y, w, h) ->
      if @currentEllipse?
        @currentEllipse.attr
          cx: x * @gw
          cy: y * @gh
          rx: w * @gw
          ry: h * @gh

    # Updating the text from the messages on the socket
    # @param  {string} t        the text of the text object
    # @param  {number} x        the x value of the object as a percentage of the original width
    # @param  {number} y        the y value of the object as a percentage of the original height
    # @param  {number} w        the width of the text box as a percentage of the original width
    # @param  {number} spacing  the spacing between the letters
    # @param  {string} colour   the colour of the text
    # @param  {string} font     the font family of the text
    # @param  {number} fontsize the size of the font (in PIXELS)
    _updateText: (t, x, y, w, spacing, colour, font, fontsize) ->
      x = x * @gw
      y = y * @gh
      unless @currentText?
        # TODO: does almost the same as calling @_drawText()
        @currentText = @raphaelObj.text(x, y, "").attr(
          fill: colour
          "font-family": font
          "font-size": fontsize
        )
        @currentText.node.style["text-anchor"] = "start" # force left align
        @currentText.node.style["textAnchor"] = "start"  # for firefox, 'cause they like to be different
        @currentShapes.push text
      else
        @currentText.attr fill: colour
        cell = @currentText.node
        cell.removeChild cell.firstChild  while cell.hasChildNodes()
        dy = textFlow(t, cell, w, x, spacing, false)
      @cursor.toFront()

    # Update zoom variables on all clients
    # @param  {Event} e the event that occurs when scrolling
    # @param  {number} delta the speed/direction at which the scroll occurred
    _zoomSlide: (e, delta) ->
      globals.connection.emitZoom delta

    # Called when the cursor is moved over the presentation.
    # Sends cursor moving event to server.
    # @param  {Event} e the mouse event
    # @param  {number} x the x value of cursor at the time in relation to the left side of the browser
    # @param  {number} y the y value of cursor at the time in relation to the top of the browser
    _onCursorMove: (e, x, y) ->
      xLocal = (e.pageX - @containerOffsetLeft) / @sw
      yLocal = (e.pageY - @containerOffsetTop) / @sh
      globals.connection.emitMoveCursor xLocal, yLocal

    # When the user is dragging the cursor (click + move)
    # @param  {number} dx the difference between the x value from panGo and now
    # @param  {number} dy the difference between the y value from panGo and now
    _panDragging: (dx, dy) ->
      sx = (@containerWidth - @gw) / 2
      sy = (@containerHeight - @gh) / 2

      # ensuring that we cannot pan outside of the boundaries
      x = (@panX - dx)
      # cannot pan past the left edge of the page
      x = (if x < 0 then 0 else x)
      y = (@panY - dy)
      # cannot pan past the top of the page
      y = (if y < 0 then 0 else y)
      if @fitToPage
        x2 = @gw + x
      else
        x2 = @containerWidth + x
      # cannot pan past the width
      x = (if x2 > @sw then @sw - (@containerWidth - sx * 2) else x)
      if @fitToPage
        y2 = @gh + y
      else
        # height of image could be greater (or less) than the box it fits in
        y2 = @containerHeight + y
      # cannot pan below the height
      y = (if y2 > @sh then @sh - (@containerHeight - sy * 2) else y)
      globals.connection.emitPaperUpdate x / @sw, y / @sh, null, null

    # When panning starts
    # @param  {number} x the x value of the cursor
    # @param  {number} y the y value of the cursor
    _panGo: (x, y) ->
      @panX = @cx
      @panY = @cy

    # When panning finishes
    # @param  {Event} e the mouse event
    _panStop: (e) ->
      @stopPanning()

    # When dragging for drawing lines starts
    # @param  {number} x the x value of the cursor
    # @param  {number} y the y value of the cursor
    _lineDragStart: (x, y) ->
      # find the x and y values in relation to the whiteboard
      sx = (@containerWidth - @gw) / 2
      sy = (@containerHeight - @gh) / 2
      @lineX = x - @containerOffsetLeft - sx + @cx
      @lineY = y - @containerOffsetTop - sy + @cy
      values = [ @lineX / @sw, @lineY / @sh, @currentColour, @currentThickness ]
      globals.connection.emitMakeShape "line", values

    # As line drawing drag continues
    # @param  {number} dx the difference between the x value from _lineDragStart and now
    # @param  {number} dy the difference between the y value from _lineDragStart and now
    # @param  {number} x  the x value of the cursor
    # @param  {number} y  the y value of the cursor
    _lineDragging: (dx, dy, x, y) ->
      sx = (@containerWidth - @gw) / 2
      sy = (@containerHeight - @gh) / 2
      # find the x and y values in relation to the whiteboard
      @cx2 = x - @containerOffsetLeft - sx + @cx
      @cy2 = y - @containerOffsetTop - sy + @cy
      if @shiftPressed
        globals.connection.emitUpdateShape "line", [ @cx2 / @sw, @cy2 / @sh, false ]
      else
        @currentPathCount++
        if @currentPathCount < MAX_PATHS_IN_SEQUENCE
          globals.connection.emitUpdateShape "line", [ @cx2 / @sw, @cy2 / @sh, true ]
        else if @currentLine?
          @currentPathCount = 0
          # save the last path of the line
          @currentLine.attrs.path.pop()
          path = @currentLine.attrs.path.join(" ")
          @currentLine.attr path: (path + "L" + @lineX + " " + @lineY)

          # scale the path appropriately before sending
          pathStr = @currentLine.attrs.path.join(",")
          globals.connection.emitPublishShape "path",
            [ Utils.stringToScaledPath(pathStr, 1 / @gw, 1 / @gh),
              @currentColour, @currentThickness ]
          globals.connection.emitMakeShape "line",
            [ @lineX / @sw, @lineY / @sh, @currentColour, @currentThickness ]
        @lineX = @cx2
        @lineY = @cy2

    # Drawing line has ended
    # @param  {Event} e the mouse event
    _lineDragStop: (e) ->
      if @currentLine?
        path = @currentLine.attrs.path
        @currentLine = null # any late updates will be blocked by this
        # scale the path appropriately before sending
        globals.connection.emitPublishShape "path",
          [ Utils.stringToScaledPath(path.join(","), 1 / @gw, 1 / @gh),
            @currentColour, @currentThickness ]

    # Creating a rectangle has started
    # @param  {number} x the x value of cursor at the time in relation to the left side of the browser
    # @param  {number} y the y value of cursor at the time in relation to the top of the browser
    _rectDragStart: (x, y) ->
      sx = (@containerWidth - @gw) / 2
      sy = (@containerHeight - @gh) / 2
      # find the x and y values in relation to the whiteboard
      @cx2 = (x - @containerOffsetLeft - sx + @cx) / @sw
      @cy2 = (y - @containerOffsetTop - sy + @cy) / @sh
      globals.connection.emitMakeShape "rect",
        [ @cx2, @cy2, @currentColour, @currentThickness ]

    # Adjusting rectangle continues
    # @param  {number} dx the difference in the x value at the start as opposed to the x value now
    # @param  {number} dy the difference in the y value at the start as opposed to the y value now
    # @param  {number} x the x value of cursor at the time in relation to the left side of the browser
    # @param  {number} y the y value of cursor at the time in relation to the top of the browser
    # @param  {Event} e  the mouse event
    _rectDragging: (dx, dy, x, y, e) ->
      # if shift is pressed, make it a square
      dy = dx if @shiftPressed
      dx = dx / @sw
      dy = dy / @sh
      # adjust for negative values as well
      if dx >= 0
        x1 = @cx2
      else
        x1 = @cx2 + dx
        dx = -dx
      if dy >= 0
        y1 = @cy2
      else
        y1 = @cy2 + dy
        dy = -dy
      globals.connection.emitUpdateShape "rect", [ x1, y1, dx, dy ]

    # When rectangle finished being drawn
    # @param  {Event} e the mouse event
    _rectDragStop: (e) ->
      if @currentRect?
        attrs = undefined
        attrs = @currentRect.attrs if @currentRect
        if attrs?
          globals.connection.emitPublishShape "rect",
            [ attrs.x / @gw, attrs.y / @gh, attrs.width / @gw, attrs.height / @gh,
              @currentColour, @currentThickness ]
      @currentRect = null

    # When first starting drawing the ellipse
    # @param  {number} x the x value of cursor at the time in relation to the left side of the browser
    # @param  {number} y the y value of cursor at the time in relation to the top of the browser
    _ellipseDragStart: (x, y) ->
      sx = (@containerWidth - @gw) / 2
      sy = (@containerHeight - @gh) / 2
      # find the x and y values in relation to the whiteboard
      @ellipseX = (x - @containerOffsetLeft - sx + @cx)
      @ellipseY = (y - @containerOffsetTop - sy + @cy)
      globals.connection.emitMakeShape "ellipse",
        [ @ellipseX / @sw, @ellipseY / @sh, @currentColour, @currentThickness ]

    # When first starting to draw an ellipse
    # @param  {number} dx the difference in the x value at the start as opposed to the x value now
    # @param  {number} dy the difference in the y value at the start as opposed to the y value now
    # @param  {number} x the x value of cursor at the time in relation to the left side of the browser
    # @param  {number} y the y value of cursor at the time in relation to the top of the browser
    # @param  {Event} e   the mouse event
    _ellipseDragging: (dx, dy, x, y, e) ->
      # if shift is pressed, draw a circle instead of ellipse
      dy = dx if @shiftPressed
      dx = dx / 2
      dy = dy / 2
      # adjust for negative values as well
      x = @ellipseX + dx
      y = @ellipseY + dy
      dx = (if dx < 0 then -dx else dx)
      dy = (if dy < 0 then -dy else dy)
      globals.connection.emitUpdateShape "ellipse",
        [ x / @sw, y / @sh, dx / @sw, dy / @sh ]

    # When releasing the mouse after drawing the ellipse
    # @param  {Event} e the mouse event
    _ellipseDragStop: (e) ->
      attrs = undefined
      attrs = @currentEllipse.attrs if @currentEllipse?
      if attrs?
        globals.connection.emitPublishShape "ellipse",
          [ attrs.cx / @gw, attrs.cy / @gh, attrs.rx / @gw, attrs.ry / @gh,
            @currentColour, @currentThickness ]
      @currentEllipse = null # late updates will be blocked by this

    # When first dragging the mouse to create the textbox size
    # @param  {number} x the x value of cursor at the time in relation to the left side of the browser
    # @param  {number} y the y value of cursor at the time in relation to the top of the browser
    _textStart: (x, y) ->
      if @currentText?
        globals.connection.emitPublishShape "text",
          [ @textbox.value, @currentText.attrs.x / @gw, @currentText.attrs.y / @gh,
            @textbox.clientWidth, 16, @currentColour, "Arial", 14 ]
        globals.connection.emitTextDone()
      @textbox.value = ""
      @textbox.style.visibility = "hidden"
      @textX = x
      @textY = y
      sx = (@containerWidth - @gw) / 2
      sy = (@containerHeight - @gh) / 2
      @cx2 = (x - @containerOffsetLeft - sx + @cx) / @sw
      @cy2 = (y - @containerOffsetTop - sy + @cy) / @sh
      @_makeRect @cx2, @cy2, "#000", 1
      globals.connection.emitMakeShape "rect", [ @cx2, @cy2, "#000", 1 ]

    # Finished drawing the rectangle that the text will fit into
    # @param  {Event} e the mouse event
    _textStop: (e) ->
      @currentRect.hide() if @currentRect?
      tboxw = (e.pageX - @textX)
      tboxh = (e.pageY - @textY)
      if tboxw >= 14 or tboxh >= 14 # restrict size
        @textbox.style.width = tboxw * (@gw / @sw) + "px"
        @textbox.style.visibility = "visible"
        @textbox.style["font-size"] = 14 + "px"
        @textbox.style["fontSize"] = 14 + "px" # firefox
        @textbox.style.color = @currentColour
        @textbox.value = ""
        sx = (@containerWidth - @gw) / 2
        sy = (@containerHeight - @gh) / 2
        x = @textX - @containerOffsetLeft - sx + @cx + 1 # 1px random padding
        y = @textY - @containerOffsetTop - sy + @cy
        @textbox.focus()

        # if you click outside, it will automatically sumbit
        @textbox.onblur = (e) =>
          if @currentText
            globals.connection.emitPublishShape "text",
              [ @value, @currentText.attrs.x / @gw, @currentText.attrs.y / @gh,
                @textbox.clientWidth, 16, @currentColour, "Arial", 14 ]
            globals.connection.emitTextDone()
          @textbox.value = ""
          @textbox.style.visibility = "hidden"

        # if user presses enter key, then automatically submit
        @textbox.onkeypress = (e) ->
          if e.keyCode is "13"
            e.preventDefault()
            e.stopPropagation()
            @onblur()

        # update everyone with the new text at every change
        _paper = @
        @textbox.onkeyup = (e) ->
          @style.color = _paper.currentColour
          @value = @value.replace(/\n{1,}/g, " ").replace(/\s{2,}/g, " ")
          globals.connection.emitUpdateShape "text",
            [ @value, x / _paper.sw, (y + (14 * (_paper.sh / _paper.gh))) / _paper.sh,
              tboxw * (_paper.gw / _paper.sw), 16, _paper.currentColour, "Arial", 14 ]

    # Called when the application window is resized.
    _onWindowResize: ->
      @_updateContainerDimensions()

    # when pressing down on a key at anytime
    _onKeyDown: (event) ->
      unless event
        keyCode = window.event.keyCode
      else
        keyCode = event.keyCode
      switch keyCode
        when 16 # shift key
          @shiftPressed = true

    # when releasing any key at any time
    _onKeyUp: ->
      unless event
        keyCode = window.event.keyCode
      else
        keyCode = event.keyCode
      switch keyCode
        when 16 # shift key
          @shiftPressed = false


  WhiteboardPaperModel
