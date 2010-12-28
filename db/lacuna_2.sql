---
--- Add fields and table to record excavator activity
---

--- alter table body add column excavated_on text;

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

