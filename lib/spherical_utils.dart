/*
 * Copyright 2013 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'dart:math';

import 'math_util.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SphericalUtil {
  /*
  * Missing simple conversions from Math class
  * Code from: https://github.com/dart-lang/sdk/issues/4211#issue-84512743
  */
  static num _toRadians(num deg) => deg * (pi / 180.0);
  static num _toDegrees(num rad) => rad * (180.0 / pi);

  /*
   * https://stackoverflow.com/a/25867068/3182210 
   */
  static String getCardinal(double angle) {
    var val = ((angle / 22.5) + 0.5).floor();
    var arr = [
      "N",
      //"NNE",
      "NE",
      //"ENE",
      "E",
      //"ESE",
      "SE",
      //"SSE",
      "S",
      //"SSW",
      "SW",
      //"WSW",
      "W",
      //"WNW",
      "NW",
      //"NNW"
    ];
    //16
    return arr[(val % 8)];
  }

  static String getDirectionName(String direction) {
    //4 basic direction
    if (direction == 'N')
      direction = 'Norte';
    else if (direction == 'S')
      direction = 'Sul';
    else if (direction == 'E')
      direction = 'Leste';
    else if (direction == 'W')
      direction = 'Oeste';
    //4+ direction
    else if (direction == 'NE')
      direction = 'Nordeste';
    else if (direction == 'SE')
      direction = 'Sudeste';
    else if (direction == 'SW')
      direction = 'Sudoeste';
    else if (direction == 'NW') direction = 'Noroeste';
    return direction;
  }

  /*
  * https://stackoverflow.com/a/31029389/3182210
  */
  static LatLngBounds toBounds(
      double latitude, double longitude, double radiusInMeters) {
    LatLng center = LatLng(latitude, longitude);
    double distanceFromCenterToCorner = radiusInMeters * sqrt(2.0);
    LatLng southwestCorner =
        SphericalUtil.computeOffset(center, distanceFromCenterToCorner, 225.0);
    LatLng northeastCorner =
        SphericalUtil.computeOffset(center, distanceFromCenterToCorner, 45.0);
    return new LatLngBounds(
        southwest: southwestCorner, northeast: northeastCorner);
  }

  /*
     * Returns the heading from one LatLng to another LatLng. Headings are
     * expressed in degrees clockwise from North within the range [-180,180).
     *
     * @return The heading in degrees clockwise from north.
     */
  static double computeHeading(LatLng from, LatLng to) {
    // http://williams.best.vwh.net/avform.htm#Crs

    double fromLat = _toRadians(from.latitude);
    double fromLng = _toRadians(from.longitude);
    double toLat = _toRadians(to.latitude);
    double toLng = _toRadians(to.longitude);
    double dLng = toLng - fromLng;
    double heading = atan2(sin(dLng) * cos(toLat),
        cos(fromLat) * sin(toLat) - sin(fromLat) * cos(toLat) * cos(dLng));
    return MathUtil.wrap(_toDegrees(heading), -180, 180);
  }

  /*
     * Returns the LatLng resulting from moving a distance from an origin
     * in the specified heading (expressed in degrees clockwise from north).
     *
     * @param from     The LatLng from which to start.
     * @param distance The distance to travel.
     * @param heading  The heading in degrees clockwise from north.
     */
  static LatLng computeOffset(LatLng from, double distance, double heading) {
    distance /= MathUtil.earthRadius;
    heading = _toRadians(heading);
    // http://williams.best.vwh.net/avform.htm#LL
    double fromLat = _toRadians(from.latitude);
    double fromLng = _toRadians(from.longitude);
    double cosDistance = cos(distance);
    double sinDistance = sin(distance);
    double sinFromLat = sin(fromLat);
    double cosFromLat = cos(fromLat);
    double sinLat =
        cosDistance * sinFromLat + sinDistance * cosFromLat * cos(heading);
    double dLng = atan2(sinDistance * cosFromLat * sin(heading),
        cosDistance - sinFromLat * sinLat);
    return new LatLng(_toDegrees(asin(sinLat)), _toDegrees(fromLng + dLng));
  }

  /*
     * Returns the location of origin when provided with a LatLng destination,
     * meters travelled and original heading. Headings are expressed in degrees
     * clockwise from North. This function returns null when no solution is
     * available.
     *
     * @param to       The destination LatLng.
     * @param distance The distance travelled, in meters.
     * @param heading  The heading in degrees clockwise from north.
     */
  static LatLng computeOffsetOrigin(
      LatLng to, double distance, double heading) {
    heading = _toRadians(heading);
    distance /= MathUtil.earthRadius;
    // http://lists.maptools.org/pipermail/proj/2008-October/003939.html
    double n1 = cos(distance);
    double n2 = sin(distance) * cos(heading);
    double n3 = sin(distance) * sin(heading);
    double n4 = sin(_toRadians(to.latitude));
    // There are two solutions for b. b = n2 * n4 +/- sqrt(), one solution results
    // in the latitude outside the [-90, 90] range. We first try one solution and
    // back off to the other if we are outside that range.
    double n12 = n1 * n1;
    double discriminant = n2 * n2 * n12 + n12 * n12 - n12 * n4 * n4;
    if (discriminant < 0) {
      // No real solution which would make sense in LatLng-space.
      return null;
    }
    double b = n2 * n4 + sqrt(discriminant);
    b /= n1 * n1 + n2 * n2;
    double a = (n4 - n2 * b) / n1;
    double fromLatRadians = atan2(a, b);
    if (fromLatRadians < -pi / 2 || fromLatRadians > pi / 2) {
      b = n2 * n4 - sqrt(discriminant);
      b /= n1 * n1 + n2 * n2;
      fromLatRadians = atan2(a, b);
    }
    if (fromLatRadians < -pi / 2 || fromLatRadians > pi / 2) {
      // No solution which would make sense in LatLng-space.
      return null;
    }
    double fromLngRadians = _toRadians(to.longitude) -
        atan2(n3, n1 * cos(fromLatRadians) - n2 * sin(fromLatRadians));
    return new LatLng(_toDegrees(fromLatRadians), _toDegrees(fromLngRadians));
  }

  /*
     * Returns the LatLng which lies the given fraction of the way between the
     * origin LatLng and the destination LatLng.
     *
     * @param from     The LatLng from which to start.
     * @param to       The LatLng toward which to travel.
     * @param fraction A fraction of the distance to travel.
     * @return The interpolated LatLng.
     */
  static LatLng interpolate(LatLng from, LatLng to, double fraction) {
    // http://en.wikipedia.org/wiki/Slerp
    double fromLat = _toRadians(from.latitude);
    double fromLng = _toRadians(from.longitude);
    double toLat = _toRadians(to.latitude);
    double toLng = _toRadians(to.longitude);
    double cosFromLat = cos(fromLat);
    double cosToLat = cos(toLat);

    // Computes Spherical interpolation coefficients.
    double angle = computeAngleBetween(from, to);
    double sinAngle = sin(angle);
    if (sinAngle < 1E-6) {
      return new LatLng(
          from.latitude + fraction * (to.latitude - from.latitude),
          from.longitude + fraction * (to.longitude - from.longitude));
    }
    double a = sin((1 - fraction) * angle) / sinAngle;
    double b = sin(fraction * angle) / sinAngle;

    // Converts from polar to vector and interpolate.
    double x = a * cosFromLat * cos(fromLng) + b * cosToLat * cos(toLng);
    double y = a * cosFromLat * sin(fromLng) + b * cosToLat * sin(toLng);
    double z = a * sin(fromLat) + b * sin(toLat);

    // Converts interpolated vector back to polar.
    double lat = atan2(z, sqrt(x * x + y * y));
    double lng = atan2(y, x);
    return new LatLng(_toDegrees(lat), _toDegrees(lng));
  }

  /*
     * Returns distance on the unit sphere; the arguments are in radians.
     */
  static double distanceRadians(
      double lat1, double lng1, double lat2, double lng2) {
    return MathUtil.arcHav(MathUtil.havDistance(lat1, lat2, lng1 - lng2));
  }

  /*
     * Returns the angle between two LatLngs, in radians. This is the same as the distance
     * on the unit sphere.
     */
  static double computeAngleBetween(LatLng from, LatLng to) {
    return distanceRadians(
        _toRadians(from.latitude),
        _toRadians(from.longitude),
        _toRadians(to.latitude),
        _toRadians(to.longitude));
  }

  /*
     * Returns the distance between two LatLngs, in meters.
     */
  static double computeDistanceBetween(LatLng from, LatLng to) {
    return computeAngleBetween(from, to) * MathUtil.earthRadius;
  }

  /*
     * Returns the length of the given path, in meters, on Earth.
     */
  static double computeLength(List<LatLng> path) {
    if (path.length < 2) {
      return 0;
    }
    double length = 0;
    LatLng prev = path[0];
    double prevLat = _toRadians(prev.latitude);
    double prevLng = _toRadians(prev.longitude);
    for (final point in path) {
      double lat = _toRadians(point.latitude);
      double lng = _toRadians(point.longitude);
      length += distanceRadians(prevLat, prevLng, lat, lng);
      prevLat = lat;
      prevLng = lng;
    }
    return length * MathUtil.earthRadius;
  }

  /*
     * Returns the area of a closed path on Earth.
     *
     * @param path A closed path.
     * @return The path's area in square meters.
     */
  static double computeArea(List<LatLng> path) => computeSignedArea(path).abs();

  /*
     * Returns the signed area of a closed path on Earth. The sign of the area may be used to
     * determine the orientation of the path.
     * 'inside' is the surface that does not contain the South Pole.
     *
     * @param path A closed path.
     * @return The loop's area in square meters.
     */
  static double computeSignedArea(List<LatLng> path) =>
      SphericalUtil.computeSignedAreaTest(path, MathUtil.earthRadius);

  /*
     * Returns the signed area of a closed path on a sphere of given radius.
     * The computed area uses the same units as the radius squared.
     * Used by SphericalUtilTest.
     */
  static double computeSignedAreaTest(List<LatLng> path, double radius) {
    int size = path.length;
    if (size < 3) {
      return 0;
    }
    double total = 0;
    LatLng prev = path[size - 1];
    double prevTanLat = tan((pi / 2 - _toRadians(prev.latitude)) / 2);
    double prevLng = _toRadians(prev.longitude);
    // For each edge, accumulate the signed area of the triangle formed by the North Pole
    // and that edge ('polar triangle').
    for (final point in path) {
      double tanLat = tan((pi / 2 - _toRadians(point.latitude)) / 2);
      double lng = _toRadians(point.longitude);
      total += polarTriangleArea(tanLat, lng, prevTanLat, prevLng);
      prevTanLat = tanLat;
      prevLng = lng;
    }
    return total * (radius * radius);
  }

  /*
     * Returns the signed area of a triangle which has North Pole as a vertex.
     * Formula derived from 'Area of a spherical triangle given two edges and the included angle'
     * as per 'Spherical Trigonometry' by Todhunter, page 71, section 103, point 2.
     * See http://books.google.com/books?id=3uBHAAAAIAAJ&pg=PA71
     * The arguments named 'tan' are tan((pi/2 - latitude)/2).
     */
  static double polarTriangleArea(
      double tan1, double lng1, double tan2, double lng2) {
    double deltaLng = lng1 - lng2;
    double t = tan1 * tan2;
    return 2 * atan2(t * sin(deltaLng), 1 + t * cos(deltaLng));
  }
}