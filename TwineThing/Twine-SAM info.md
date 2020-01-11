# Screen:
* 256x192 resolution.

# Images:
* Always 256x144, on the top of the screen before the text.
* Real (displayed) size is 256x136. Last lines end up hidden by the text.

# Text:
* Only displayed once a `<<pause>>` command or the end of the passage is reached.
* Characters are always 8x8.
* Text size is 30 characters per line, with 6 lines per screen.
* Automatic line breaks/word-wraps.
* Cuts off the last few lines of the image.
* One 8x8 empty space on either side.
* 8 empty pixels between the last line and the bottom of the screen.

# Selections:
* Only displayed when the interpreter/VM reaches the end of the passage.
* Has an indicator, always on the left side of the screen.
* Up and left move the selector up, down and right move the selector down.
* Moving the selection makes a beep.
* No looping. Just stops when you reach the ends of the list.
* Buttons 1 and 2 make the selection. (Should be just one button)
* Buttons only do things when *released*. (Not important)

# Commands:
* `<<pause>>`: Stops the current screen until the player presses a button.
* `<<jump PassageName>>`: Jumps to a passage.
* `<<call PassageName>>`: Jumps to a passage. Returns to the caller when a `<<return>>` is encountered.
* `<<return>>`: Returns to the previous passage. (?)
* `<<music "Filename.epsgmod">>`: Changes to the specified song.
* `[img[PICTURE.png]]`: Sets the image to the specified file.
* `* [[COMMAND TEXT|PassageName]]`: Adds a selection. Jumps to the specified passage.
* `<<if Variable is Expression>>`: Executes the code between it and the next `<<endif>>` if `Expression` evaluates to true.
* `<<endif>>`: Ends an `<<if>>`.
* `<<set Variable = Expression>>`: Sets the variable to the value of the specified expression.
* `<<print Variable>>`: Prints the value of the variable.

# Expressions:
* Logical operations:
    * `expr1 or expr2`: returns **true** if either of the expressions is true.
    * `expr1 and expr2`: returns true if both expressions are true.
    * `not expr`: Negates the expression, turning false into true and vice versa.
    * Constants: `true` and `false` are supported. Numeric values follow C boolean casting rules.
* Comparison operators:
    * `lhs == rhs`: True if both sides have the same value.
    * `lhs is rhs`: True if both sides have the same value.
    * `lhs != rhs`: True if both sides have different values.
    * `lhs <> rhs`: True if both sides have different values.
    * `lhs < rhs`: True if the left side is lesser than the right side.
    * `lhs > rhs`: True if the left side is greater than the right side.
    * `lhs <= rhs`: True if the left side is lesser than or equal to the right side.
    * `lhs >= rhs`: True if the left side is greater than or equal to the right side.
* Arithmetic operations:
    * `lhs + rhs`: Adds the value of the right side to the left side.
    * `lhs - rhs`: Subtracts the value of the right side from the left side.
    * `lhs * rhs`: Multiplies the left side by the right side.
    * `lhs / rhs`: Divides the left side by the right side.
    * `lhs % rhs`: Returns the remainder of the division of the left side by the right side.
* Unary operations:
    * `-expr`: Negates the value as an int.
