--- Create the schema for the Lacuna Expanse API
--- NOTE the 'star' table will need to be set up from the stars.csv file
---
CREATE TABLE api_hits (
    id          integer primary key autoincrement,
    script      text,
    on_date     text,
    hits        integer
);
CREATE TABLE body (
    id          integer primary key autoincrement,
    orbit       integer,
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
CREATE TABLE distance (
    id          integer primary key autoincrement,
    from_id     integer,
    to_id       integer,
    distance    integer,
    foreign key(from_id) references body(id),
    foreign key(to_id) references body(id)
);
CREATE TABLE excavation (
    id          integer primary key autoincrement,
    body_id     integer,
    on_date     text,
    resource_genre  text,
    resource_type   text,
    resource_qty    integer,
    foreign key(body_id) references body(id)
);
CREATE TABLE link_body__ore (
    id          integer primary key autoincrement,
    body_id     integer,
    ore_id      integer,
    quantity    integer,
    foreign key(body_id) references body(id),
    foreign key(ore_id) references ore(id)
);
CREATE TABLE ore (
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

CREATE TABLE star (
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
--- scan_date
---    the date the probe scan was made
---    null - the scan has not been made yet
--- status
---    1 - probe is travelling to this star
---    2 - another colony or an alliance member sent the probe
---    3 - our probe is present at the star
---    4 - the probe can now be abandoned (all bodies have been excavated)
---    5 - we deleted the probe from our observatory

CREATE INDEX idx_distance__distance on distance(distance);
CREATE INDEX idx_distance__from_id on distance(from_id);
CREATE INDEX idx_distance__to_id on distance(to_id);
