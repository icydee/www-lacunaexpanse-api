---
--- Add fields and table to record excavator activity
---

create table excavation (
    id          integer primary key autoincrement,
    body_id     integer,
    on_date     text,
    resource_genre  text,
    resource_type   text,
    resource_qty    integer,
    foreign key(body_id) references body(id)
);

--- examples of finds
---    resource_genre   = nothing/resource/glyph/plan
---    resource_type    = (for genre 'resource' or 'glyph') 'calcopyrite','trona', etc.
---                       (for genre 'plan') 'Interdimensional Rift','Volcano'
---    resource_qty     = for genre 'resource' the amount of resource, for genre 'plan' the building level

--- table to keep track of API calls per script

create table api_hits (
    id          integer primary key autoincrement,
    script      text,
    on_date     text,
    hits        integer
);

--- ensure we don't probe/excavate the same star in 30 days

create table probe_visit (
    id          integer primary key autoincrement,
    star_id     integer,
    on_date     text,
    foreign key(star_id) references star(id)
);
