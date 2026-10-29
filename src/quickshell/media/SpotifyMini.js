.pragma library

function defaults() {
    return { preferredClient: "", showArtwork: true, pageSize: 30, bridgeUrl: "", bridgeToken: "" };
}

function parseProfile(text) {
    var profile = defaults();
    try {
        var data = JSON.parse(text);
        if (!data || typeof data !== "object" || Array.isArray(data)) return profile;
        for (var key of ["preferredClient", "bridgeToken"]) {
            if (typeof data[key] === "string") profile[key] = data[key];
        }
        if (typeof data.bridgeUrl === "string" && /^http:\/\/127\.0\.0\.1:\d+$/.test(data.bridgeUrl)) profile.bridgeUrl = data.bridgeUrl;
        if (typeof data.showArtwork === "boolean") profile.showArtwork = data.showArtwork;
        if (typeof data.pageSize === "number") profile.pageSize = Math.min(50, Math.max(1, Math.floor(data.pageSize)));
    } catch (_) { /* Keep the compact defaults if the profile is unavailable. */ }
    return profile;
}

function isSpotify(player) {
    if (!player) return false;
    var bus = String(player.dbusName || "").toLowerCase();
    var desktop = String(player.desktopEntry || "").toLowerCase().replace(/\.desktop$/, "");
    return /^org\.mpris\.mediaplayer2\.spotify(?:[.\-]|$)/.test(bus) ||
        desktop === "spotify" || desktop === "com.spotify.client";
}

function selectPlayer(players, preferredClient) {
    var candidates = [];
    for (var player of players || []) {
        if (isSpotify(player)) candidates.push(player);
    }
    var preferred = candidates.find(function(player) { return player.dbusName === preferredClient; });
    return preferred || candidates.find(function(player) { return player.isPlaying; }) ||
        candidates.find(function(player) { return player.canControl; }) || candidates[0] || null;
}
