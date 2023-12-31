#! /usr/bin/env ruby

# Generate initial character row (code/attr pair) data.
# This will allow development of the character rendering logic
# without actually needing external data (the interface to
# the host system will be the last part of the project.)

# xterm colors (add 8 to make intense)
COLORS = {
  'black' => 0,
  'red' => 1,
  'green' => 2,
  'yellow' => 3,
  'blue' => 4,
  'magenta' => 5,
  'cyan' => 6,
  'gray' => 7,
}

def mkattr(bg, fg)
  return ((bg << 4) | fg).chr
end

text = ''
attr = ''

# Some gray on black text
text += "All your base are belong to us "
attr += mkattr(COLORS['black'], COLORS['gray']) * (text.length - attr.length)

# Generate various bg/fg attribute combinations
text += "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()"
(0..(text.length - attr.length - 1)).each do |i|
  attr += mkattr(i/16, i%16)
end

puts "// Generated by gen_init_chrowbuf_data.rb"
puts ""

count = text.length
(0..count-1).each do |i|
  val = (attr[i].ord << 8 | text[i].ord)
  puts "chrow_data[8'd#{i}] = 16'd#{val};"
end

j = count
while j < 256
  puts "chrow_data[8'd#{j}] = 16'd0;"
  j += 1
end

puts ""
s = "vim"
puts "// #{s}:ft=verilog:"
