// cube.scad
// Example model. You can use shared config/modules like:
// include <defaults.scad>
// use <fillets.scad>
// use <holes.scad>
// use <profiles.scad>
cube_size = 20;   // change this → automatic rebuild

cube([cube_size, cube_size, cube_size], center = true);
