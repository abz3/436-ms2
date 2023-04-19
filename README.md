# Milestone 1
Usage

Make
xterm h1 h2

On h2, ./receive.py
On h1, ./send.py

## Main files altered
hw2.p4 
The main file for this homework.

new_headers.py
Introduces the request and return val headers and binds appropriately.

send.py
Python file for sending requests. Further instructions are in the comments.

receive.py
Python file for receiving requests and prints out the val in returnval.

Makefile
Minor change to the correct make file.

diamond-topo/s1-runtime.json
Adds ingress tables for the different kvs requests.

diamond-topo/topology.json
Changes to topology for the project.

## Test cases and scripts used
send.py details ways to test the program. We used a variety of test cases including e.g.

[("PUT", 0, 10), ("PUT", 0, 12), ("PUT", 2, 5), 
("GET", 0, 0), ("GET", 0, 1), ("GET", 0, 2), ("GET", 2, 0), 
("RANGE", 0, 0, 0), ("RANGE", 0, 0, 1), ("RANGE", 0,  2, 0), 
("SELECT", 5, "<", 0), ("SELECT", 0, "<=", 0), ("SELECT", 0, "==", 1)]

Which returns 10 for the first get, 12 for the second get, 0 for the third get, 5 for the fourth get.
10 for the first range, 12 for the second range, 10, 0, 12 for the third range
10, 0, 5, 0, 0 for the first select, 10 for the second select, 12 for the third select.


[("PUT", 0, 10), ("GET", 0, 0), ("PUT", 0, 11), ("GET", 0, 0)]

Returns 10, 10


[("PUT", 0, 10), ("GET", 0, 1), ("PUT", 0, 11), ("GET", 0, 1)]

Returns 0, 11


[("PUT", 1, 10), ("GET", 1, 1), ("RANGE", 1, 10, 1) ,("PUT", 1, 11), ("GET", 1, 1), ("RANGE", 1, 10, 1)]

Returns 0, [0,0,0,0,0,0,0,0,0,0], 11, [11,0,0,0,0,0,0,0,0,0]


[("PUT", 100, 10), ("PUT", 101, 10), ("PUT", 104, 10), ("RANGE", 100, 105, 0)]

Returns 10, 10, 0, 0, 10, 0

[("PUT", 1015, 10), ("PUT", 1017, 11), ("PUT", 1020, 13), ("RANGE", 1016, 1021, 0), ("SELECT", 1017, ">", 0), ("SELECT", 1017, ">=", 0)]

Returns [0,11,0,0,13,0], [0,0,13,0,0,0,0], [11,0,0,13,0,0,0,0]

We also tested other test cases not listed here to stress the load. Remarkably very large selects and ranges
can be often handled without breaking them up.

## Project report
Attached to this folder as MS1.pdf
