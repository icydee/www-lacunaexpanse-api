--- Create the schema for the Lacuna Expanse API
--- NOTE the 'star' table will need to be set up from the stars.csv file
---
CREATE TABLE server (
    server_id   integer not null,
    url         text
);

insert into server (server_id, url) values (1, 'http://us1.lacunaexpanse.com/');

--- MORE TO BE DEFINED
CREATE TABLE empire (
    server_id   integer not null,
    empire_id   integer not null,
    foreign key(server_id) references server(id),
    primary key(server_id,empire_id)
);

CREATE TABLE api_hits (
    server_id   integer not null,
    empire_id   integer not null,
    on_date     text not null,
    hits        integer,
    foreign key(server_id) references server(id),
    foreign key(empire_id) references empire(id),
    primary key(server_id,empire_id)
);

--- last_scan_date - the last date this star was probed
--- by a probe from empire_id
---
CREATE TABLE star (
    server_id   integer not null,
    star_id     integer not null,
    name        text,
    x           integer not null,
    y           integer not null,
    color       text,
    sector      text,
    foreign key(server_id) references server(id),
    primary key(server_id,star_id)
);

CREATE TABLE star_last_probe (
    server_id   integer not null,
    star_id     integer not null,
    empire_id   integer not null,
    on_date     text,
    foreign key(server_id) references server(id),
    foreign key(star_id) references star(id),
    foreign key(empire_id) references empire(id),
    primary key(server_id,star_id,empire_id)
);

CREATE TABLE body (
    server_id   integer not null,
    body_id     integer not null,
    orbit       integer,
    name        text,
    x           integer,
    y           integer,
    image       text,
    size        integer,
    type        text,
    star_id     integer,
    empire_id   integer,
    water       integer,
    foreign key(server_id) references server(id),
    foreign key(body_id) references body(id),
    foreign key(star_id) references star(id),
    foreign key(empire_id) references empire(id),
    primary key(server_id,body_id)
);

-- The date that a body was last visited by a probe from an empire
--
CREATE TABLE body_last_visit (
    server_id   integer not null,
    empire_id   integer not null,
    body_id     integer not null,
    on_date     text,
    foreign key(server_id) references server(id),
    foreign key(body_id) references body(id),
    foreign key(empire_id) references empire(id),
    primary key(server_id,body_id,empire_id)
);

--- distance from one star to another
---
CREATE TABLE star_distance (
    server_id       integer not null,
    from_star_id    integer,
    to_star_id      integer,
    distance        integer,
    foreign key(from_star_id) references star(id),
    foreign key(to_star_id) references star(id),
    primary key(server_id,from_star_id,to_star_id)
);

CREATE TABLE excavation (
    server_id       integer not null,
    empire_id       integer not null,
    body_id         integer not null,
    on_date         text,
    resource_genre  text,
    resource_type   text,
    resource_qty    integer,
    foreign key(server_id) references server(id),
    foreign key(body_id) references body(id),
    foreign key(empire_id) references empire(id),
    primary key(server_id,empire_id,body_id)
);

CREATE TABLE link_body__ore (
    server_id   integer not null,
    body_id     integer,
    ore_id      integer,
    quantity    integer,
    foreign key(server_id) references server(id),
    foreign key(body_id) references body(id),

CREATE TABLE excavation (
    id              integer not null auto_increment,
    server_id       integer not null,
    empire_id       integer not null,
    body_id         integer,
    body_name       varchar(32),
    on_date         varchar(24),
    colony_id       integer,
    resource_genre  text,
    resource_type   text,
    resource_qty    integer,
    foreign key(server_id) references server(id),
    foreign key(body_id) references body(id),
    foreign key(empire_id) references empire(id),
    foreign key(colony_id) references body(id),
    primary key(id)
);

--- alter table excavation add column colony_id integer after on_date;
--- alter table excavation add foreign key(colony_id) references body(id);

CREATE TABLE link_body__ore (
    server_id   integer not null,
    body_id     integer,
    ore_id      integer,
    quantity    integer,
    foreign key(server_id) references server(id),
    foreign key(body_id) references body(id),
    foreign key(ore_id) references ore(id),
    primary key(server_id,body_id,ore_id)
);

CREATE TABLE config (
