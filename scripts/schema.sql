--- Database

create table star (
    id      integer,
    name    text,
    color   text,
    x       integer,
    y       integer
);

create table distance (
    id          integer primary key autoincrement,
    id_from     integer,
    id_to       integer,
    distance    integer,
);
