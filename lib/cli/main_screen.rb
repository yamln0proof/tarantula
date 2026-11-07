#Libraries
require 'curses'

Curses.init_screen()

my_str = "Hello, Curses!"

main_window = Curses::Window.new(10, 10, 10, 10)

main_window.box("|", "-")
main_window.refresh

win = main_window.subwin(8, 8, 11, 11)

win.setpos(1, 1)
win.addstr(my_str)

win << "Press any key to exit..."

win.refresh
win.getch
win.close