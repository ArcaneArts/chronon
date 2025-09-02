const dbName = process.env.MONGO_INITDB_DATABASE || "appdb";
db = db.getSiblingDB("admin");
db.getSiblingDB(dbName).my_init.insertOne({ createdAt: new Date() });
db.getSiblingDB(dbName).createUser({
  user: process.env.APP_USER || "appuser",
  pwd: process.env.APP_PASS || "apppass",
  roles: [{ role: "readWrite", db: dbName }]
});