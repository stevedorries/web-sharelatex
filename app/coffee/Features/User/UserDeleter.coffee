User = require("../../models/User").User
NewsletterManager = require "../Newsletter/NewsletterManager"
ProjectDeleter = require("../Project/ProjectDeleter")
logger = require("logger-sharelatex")
SubscriptionHandler = require("../Subscription/SubscriptionHandler")
async = require("async")
InstitutionsAPI = require("../Institutions/InstitutionsAPI")
Errors = require("../Errors/Errors")
{db, ObjectId} = require("../../infrastructure/mongojs")

module.exports = UserDeleter =

	softDeleteUser: (user_id, callback = (err)->)->
		if !user_id?
			logger.err "user_id is null when trying to delete user"
			return callback(new Error("no user_id"))
		User.findById user_id, (err, user)->
			return callback(err) if err?
			return callback(new Errors.NotFoundError("user not found")) unless user?
			async.series([
				(cb) ->
					UserDeleter._cleanupUser user, cb
				(cb) ->
					ProjectDeleter.softDeleteUsersProjects user._id, cb
				(cb) ->
					user.deletedAt = new Date()
					db.deletedUsers.insert user, cb
				(cb) ->
					user.remove cb
			], callback)

	deleteUser: (user_id, callback = ()->)->
		if !user_id?
			logger.err "user_id is null when trying to delete user"
			return callback("no user_id")
		User.findById user_id, (err, user)->
			if err?
				return callback(err)
			logger.log user:user, "deleting user"
			async.series [
				(cb)->
					UserDeleter._cleanupUser user, cb
				(cb)->
					ProjectDeleter.deleteUsersProjects user._id, cb
				(cb)->
					user.remove cb
			], (err)->
				if err?
					logger.err err:err, user_id:user_id, "something went wrong deleteing the user"
				callback err

	_cleanupUser: (user, callback) ->
		return callback(new Error("no user supplied")) unless user?
		async.series([
			(cb)->
				NewsletterManager.unsubscribe user, cb
			(cb)->
				SubscriptionHandler.cancelSubscription user, cb
			(cb)->
				InstitutionsAPI.deleteAffiliations user._id, cb
		], callback)
