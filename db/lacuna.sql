create table star (
    id          integer primary key autoincrement,
    name        text,
    x           integer not null,
    y           integer not null,
    color       text,
    sector      text,
    scan_date   text,
    empire_id   integer,
    status      integer
);
--- status
---    1 - pending
---    2 - arrived

create table distance (
    id          integer primary key autoincrement,
    from_id     integer,
    to_id       integer,
    distance    integer,
    foreign key(from_id) references body(id),
    foreign key(to_id) references body(id)
);
create index idx_distance__from_id on distance(from_id);
create index idx_distance__to_id on distance(to_id);
create index idx_distance__distance on distance(distance);

create table body (
    id          integer primary key autoincrement,
    name        text,
    x           integer,
    y           integer,
    image       text,
    size        integer,
    type        text,
    star_id     star,
    empire_id   integer,
    water       integer,
    foreign key(star_id) references star(id)
);

create table ore (
    id          integer primary key autoincrement,
    name        text
);

insert into ore (id, name) values (1, 'anthracite');
insert into ore (id, name) values (2, 'bauxite');
insert into ore (id, name) values (3, 'beryl');
insert into ore (id, name) values (4, 'chalcopyrite');
insert into ore (id, name) values (5, 'chromite');
insert into ore (id, name) values (6, 'fluorite');
insert into ore (id, name) values (7, 'galena');
insert into ore (id, name) values (8, 'goethite');
insert into ore (id, name) values (9, 'gold');
insert into ore (id, name) values (10, 'gypsum');
insert into ore (id, name) values (11, 'halite');
insert into ore (id, name) values (12, 'kerogen');
insert into ore (id, name) values (13, 'magnetite');
insert into ore (id, name) values (14, 'methane');
insert into ore (id, name) values (15, 'monazite');
insert into ore (id, name) values (16, 'rutile');
insert into ore (id, name) values (17, 'sulfur');
insert into ore (id, name) values (18, 'trona');
insert into ore (id, name) values (19, 'uraninite');
insert into ore (id, name) values (20, 'zircon');

create table link_body__ore (
    id          integer primary key autoincrement,
    body_id     integer,
    ore_id      integer,
    quantity    integer,
    foreign key(body_id) references body(id),
    foreign key(ore_id) references ore(id)
);
