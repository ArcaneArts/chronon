// creates DB by writing something; also adds an app user
const dbName = process.env.MONGO_INITDB_DATABASE || "mongo";

// connect as root to admin
db = db.getSiblingDB("admin");

// create application database and a starter collection
db.getSiblingDB(dbName).my_init.insertOne({createdAt: new Date()});

// create a non-root user scoped to the app DB
db.getSiblingDB(dbName).createUser({
  user: "mongo",
  pwd: "mongo",
  roles: [{ role: "readWrite", db: dbName }]
});