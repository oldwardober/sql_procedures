
------- Stored procedures ideas for AdventureWorks database --------


-- 1. Search for basic contact info for a given person (you can use the full name or only part of a name)

create procedure dbo.uspSearchContactInfo (@FullName varchar(100))

as

begin
	
	with contact_info as (
		select 
			a.BusinessEntityID,
			case 
				when a.MiddleName is not null then a.FirstName + ' ' + a.MiddleName + ' ' + a.LastName
				else a.FirstName + ' ' + a.LastName
			end as FullName,
			case 
				when c.AddressLine2 is null then c.AddressLine1 + ', ' + c.City
				else c.AddressLine1 + ' ' + c.AddressLine2 + ', ' + c.City
			end as Address,
			g.Name as Country,
			d.PhoneNumber,
			e.EmailAddress
		from Person.Person a
		left join Person.BusinessEntityAddress b on a.BusinessEntityID=b.BusinessEntityID
		left join Person.Address c on b.AddressID = c.AddressID
		left join Person.PersonPhone d on a.BusinessEntityID = d.BusinessEntityID
		left join Person.EmailAddress e on a.BusinessEntityID = e.BusinessEntityID
		left join Person.StateProvince f on f.StateProvinceID = c.StateProvinceID
		left join Person.CountryRegion g on g.CountryRegionCode = f.CountryRegionCode
		)

	select *
	from contact_info
	where FullName like '%' + @FullName + '%'

end

-- usage example 
dbo.uspSearchContactInfo Johnson



-- 2. Search for products within a given price range, category and subcategory

-- this procedure uses dynamic SQL which allows user to ommit two arguments (max price and subcategory)

create procedure dbo.uspSearchProducts (
		@Category varchar(100),
		@MinPrice varchar(100), 
		@MaxPrice varchar(100) = null, -- this argument is optional
		@Subcategory varchar(100) = null -- this argument is optional 
		)
		
as 

begin 

	declare @FixedPart varchar(max) = 
		'select 
			a.ProductID,
			a.Name as ProductName,
			b.Name as Subcategory,
			c.Name as Category,
			a.ListPrice as Price
		from Production.Product a
		left join Production.ProductSubcategory b on a.ProductSubcategoryID = b.ProductSubcategoryID
		left join Production.ProductCategory c on b.ProductCategoryID = c.ProductCategoryID '

	declare @WhereStatement varchar(max) = 
		case 
			when @MaxPrice is null and @Subcategory is null then 
				'where a.ListPrice >= ' + @MinPrice + ' and c.Name = ' + '''' + @Category + ''''
			when @MaxPrice is null and @Subcategory is not null then 
				'where a.ListPrice >= ' + @MinPrice + ' and c.Name = ' + '''' + @Category + '''' + ' and b.Name = ' + '''' + @Subcategory + ''''
			when @MaxPrice is not null and @Subcategory is null then 
				'where a.ListPrice between '  + @MinPrice + ' and ' + @MaxPrice + ' and c.Name = ' + '''' + @Category + ''''
			else 
				'where a.ListPrice between '  + @MinPrice + ' and ' + @MaxPrice + ' and c.Name = ' + '''' + @Category + '''' + ' and b.Name = ' + '''' + @Subcategory + ''''
		end

	declare @Output varchar(max) = @FixedPart + @WhereStatement

	exec(@Output)

end

-- usage examples
exec dbo.uspSearchProducts Bikes, 3000 -- all bikes > $3000
exec dbo.uspSearchProducts Clothing, 0, 100, Jerseys -- jersey $0-100
exec dbo.uspSearchProducts Components, 100, null, Brakes -- brakes > $500
exec dbo.uspSearchProducts Accessories, 0, 20 -- all accessories < $20


-- 3. For a previous procedure it may be useful to get a list of subcategories grouped by category. We can create a view for that.
--    It's a nice example of practical use of 'stuff' function and 'for xml path'.

create view Production.vSubcategories

as

	with temp as (
		select b.Name as SubName, a.Name as CatName, a.ProductCategoryID as id
		from Production.ProductCategory a 
		left join Production.ProductSubcategory b on a.ProductCategoryID = b.ProductCategoryID
		)

	select 
		id,
		CatName as ProductCategory,
		stuff((select ', ' + SubName from temp t1 where t1.id = t2.id for xml path ('')), 1, 1, '') as Subcategories
	from temp t2 
	group by id, CatName

--usage
select * from Production.vSubcategories

 
 --4. Get a list of top 10 stores by Total Revenue in a given country and for a given year
 -- possible countries (codes): AU, CA, DE, FR, GB, US
 -- possible years: 2011-2014

create procedure dbo.uspBestStores (@Country varchar(8), @Year int)

as 

begin

	 select 
		top(10) c.Name Store,
		sum(a.TotalDue) TotalRevenue
	 from Sales.SalesOrderHeader a
	 left join Sales.Customer b on a.CustomerID = b.CustomerID
	 left join Sales.Store c on b.StoreID = c.BusinessEntityID
	 left join Sales.SalesTerritory d on d.TerritoryID = a.TerritoryID
	 where d.CountryRegionCode = @Country and year(a.OrderDate) = @Year and c.Name is not null
	 group by c.Name
	 order by 2 desc

end 

-- usage examples
exec dbo.uspBestStores 'US', 2011
exec dbo.uspBestStores 'DE', 2014
exec dbo.uspBestStores 'AU', 2013

 

 