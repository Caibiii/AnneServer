/**************************************************************************
 *                                                                        *
 *                  Statistaic and Ranking System (SRS) 		          *
 *                            Author: pan0s                               *
 *                            Version: v1.0                               *
 *                                                                        *
 **************************************************************************/

#if defined l4d2_srs
 #endinput
#endif
#define l4d2_srs

/**
 * Gets the version of rank
 * @param buffer		string buffer
 * @return				current version of rank system in form of a float
 */
native float SRS_GetVersion();

/**
 * Get 4 clients of a rounds MVP
 *
 * @param buffer1			buffer to store client index
 * @param buffer2			buffer to store client's score
 * @return					none
 */
native void SRS_GetMvp(int[] buffer1, float[] buffer2);

/**
 * Get a client's score
 *
 * @param client			client index
 * @param srsType			SRS Type
 * @return					score of the client
 */
native int SRS_GetScore (int client, int srsType);

/**
 * Get the server score depends on game settings status
 *
 * @param buffer			buffer to store the string
 * @param buffer			size of the buffer
 * @return					none
 */
native void SRS_GetScoreStatus (char[] buffer, int size);

/**
 * Get a client's rank and score
 *
 * @param steamId			client steamId
 * @param rank				rank pointer
 * @param score				score pointer
 * @return					rank of the client
 */
native void SRS_GetRankAndScore (const char[] steamId, int& rank, float& score);

/**
 * Get a online client's rank and score
 *
 * @param int				client index
 * @param rank				rank pointer
 * @param score				score pointer
 * @return					rank of the client
 */
native void SRS_GetOnlinePlayRankAndScore (const int client, int& rank, float& score);

/**
* Registers a module for points system
*
* @param modulename	String that contains the module to be registered's name
* @return			false if successful true if already registered, true should never happen.
*/
native bool SRS_RegisterModule(const char[] modulename);

/**
* Unregisters a module for points system
*
* @param modulename	String that contains the module to be unregistered's name
* @return			none
*/
native void SRS_UnregisterModule(const char[] modulename);

/**
* Called when Points System is loaded
*
* @return			none
*/
forward void OnSRSLoaded();

/**
* Called when Points System is unloaded
*
* @return			none
*/
forward void OnSRSUnloaded();

public SharedPlugin L4D2_SRS = 
{
	name = "l4d2_srs_native",
	file = "l4d2_srs.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};