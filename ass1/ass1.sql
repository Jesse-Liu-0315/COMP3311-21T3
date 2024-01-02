-- COMP3311 21T3 Assignment 1
--
-- Fill in the gaps ("...") below with your code
-- You can add any auxiliary views/function that you like
-- The code in this file MUST load into a database in one pass
-- It will be tested as follows:
-- createdb test; psql test -f ass1.dump; psql test -f ass1.sql
-- Make sure it can load without errorunder these conditions


-- Q1: oldest brewery

create or replace view Q1(brewery)
as
select name from breweries where founded = (select min(founded) from breweries)
;

-- Q2: collaboration beers

create or replace view Q2(beer)
as
select a1.name from beers a1 join brewed_by b1 on (a1.id = b1.beer), beers a2 join brewed_by b2 on (a2.id = b2.beer) where b1.beer = b2.beer and b1.brewery < b2.brewery
;

-- Q3: worst beer

create or replace view Q3(worst)
as
select name from beers where rating = (select min(rating) from beers)
;

-- Q4: too strong beer

create or replace view Q4(beer,abv,style,max_abv)
as
select a.name, a.abv, b.name, b.max_abv from beers a join styles b on (a.style = b.id) where a.abv > b.max_abv
;

-- Q5: most common style

create or replace view Q5(style)
as
select name from styles where id = (select style from beers group by style order by count(*) desc limit 1)
;

-- Q6: duplicated style names

create or replace view Q6(style1,style2)
as
select a.name, b.name from styles a, styles b where lower(a.name) = lower(b.name) and a.name < b.name
;

-- Q7: breweries that make no beers

create or replace view Q7(brewery)
as
select name from breweries where not exists(select * from brewed_by where breweries.id = brewed_by.brewery)
;

-- Q8: city with the most breweries

create or replace view Q8(city,country)
as
select metro, country from locations where 
metro = (select a.metro from breweries b join locations a on (a.id = b.located_in) where a.metro is not null group by a.metro order by count(*) desc limit 1) limit 1
;

-- Q9: breweries that make more than 5 styles

create or replace view Q9(brewery,nstyles)
as
select a.name, count(distinct c.style) from breweries a join brewed_by b on (a.id = b.brewery) join beers c on (b.beer = c.id) group by a.id having count(distinct c.style) > 5
;

-- Q10: beers of a certain style
create or replace view q10_view(id, beer, brewery, style, year, abv) as
select a.id, a.name, c.name, d.name, a.brewed, a.abv from beers a join brewed_by b on (a.id = b.beer) join breweries c on (b.brewery = c.id) join styles d on (a.style = d.id);
create type BeerInfo as (beer text, brewery text, style text, year YearValue, abv ABVvalue);
create or replace function
	Q10(_style text) returns setof BeerInfo
as $$ 
declare
	result BeerInfo;
begin
	for result in select beer, string_agg(brewery, ' + ' order by brewery), style, year, abv from q10_view where _style = style group by id, beer, style, year, abv order by beer loop
	return next result;
	end loop;
	return;
end;
$$
language plpgsql;

-- Q11: beers with names matching a pattern
create or replace view q11_view(id, beer, brewery, style, abv) as
select a.id, a.name, c.name, d.name, a.abv from beers a join brewed_by b on (a.id = b.beer) join breweries c on (b.brewery = c.id) join styles d on (a.style = d.id);
create type PartialName as (beer text, brewery text, style text, abv ABVvalue);
create or replace function
    Q11(partial_name text) returns setof text
as $$
declare
    result PartialName;
begin
	for result in select beer, string_agg(brewery, ' + ' order by brewery), style, abv from q11_view where position(lower(partial_name) in lower(beer)) > 0 group by id, beer, style, abv order by beer loop
	return next  '"' || result.beer || '", ' || result.brewery || ', ' ||result.style || ', ' || result.abv || '% ABV';
	end loop;
	return;
end;
$$
language plpgsql;

-- Q12: breweries and the beers they make
create or replace view q12_view1(id, brewery, founded, town, metro, region, contry) as
select a.id, a.name, a.founded, b.town, b.metro, b.region, b.country from breweries a join locations b on (a.located_in = b.id);
create type q12Brewery as (id integer, brewery text, founded YearValue, town text, metro text, region text, country text);
create or replace view q12_view2(id, beer, style, year, abv, brewery_id) as
select a.id, a.name, d.name, a.brewed, a.abv, c.id from beers a join brewed_by b on (a.id = b.beer) join breweries c on (b.brewery = c.id) join styles d on (a.style = d.id);
create type q12Beer as (beer text, style text, year YearValue, abv ABVvalue);
create or replace function
    Q12(partial_name text) returns setof text
as $$
declare
	result1 q12Brewery;
	result2 q12Beer;
begin
	for result1 in select id, brewery, founded, town, metro, region, contry from q12_view1 where position(lower(partial_name) in lower(brewery)) > 0 loop
	return next result1.brewery || ', founded ' || result1.founded;
	if result1.region is not null then
	if result1.town is not null then`
	return next 'located in ' || result1.town || ', ' || result1.region || ', ' || result1.country;
	elsif result1.metro is not null then
	return next 'located in ' || result1.metro || ', ' || result1.region || ', ' || result1.country;
	else
	return next 'located in ' || result1.region || ', ' || result1.country;
	end if;
	else
	if result1.town is not null then
	return next 'located in ' || result1.town || ', ' || result1.country;
	elsif result1.metro is not null then
	return next 'located in ' || result1.metro || ', ' || result1.country;
	else
	return next 'located in ' || ', ' || result1.country;
	end if;
	end if;
	for result2 in select a.beer, a.style, a.year, a.abv from q12_view2 a join q12_view1 b on (a.brewery_id = b.id) where b.id = result1.id loop
	return next  '  "' || result2.beer || '", ' ||result2.style || ', ' || result2.year || ', ' || result2.abv || '% ABV';
	end loop;
	end loop;
	return;
end;
$$
language plpgsql;