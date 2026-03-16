import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ridematch/models/car/carmodel.dart';

class Ride {
  final String id;
  final String driverId; // ✅ Add driverId
  final String driverName;
  final String driverImage;
  final String driverPhone;
  final double rating;
  final CarDetails? carDetails;
  final String from;
  final String to;
  final int seats;
  final double amount;
  final String? date;
  final String? time;

  final LatLng? pickupLocation;
  final LatLng? dropLocation;

  Ride({
    required this.id,
    required this.driverId, // ✅
    required this.driverName,
    required this.driverImage,
    required this.driverPhone,
    required this.rating,
    this.carDetails,
    required this.from,
    required this.to,
    required this.seats,
    required this.amount,
    this.date,
    this.time,
    this.pickupLocation,
    this.dropLocation,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['_id'] ?? '',
      driverId: json['driverId'] ?? '', // ✅ parse driverId
      driverName: json['driverName'] ?? '',
      driverImage: json['driverImage'] ?? '',
      driverPhone: json['driverPhone'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      carDetails: json['carDetails'] != null
          ? CarDetails.fromJson(json['carDetails'])
          : null,
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      seats: json['seats'] ?? json['availableSeats'] ?? 0,
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'],
      time: json['time'],
      pickupLocation: json['pickupLocation'] != null
          ? LatLng(
        (json['pickupLocation']['lat'] ?? 0).toDouble(),
        (json['pickupLocation']['lng'] ?? 0).toDouble(),
      )
          : null,
      dropLocation: json['dropLocation'] != null
          ? LatLng(
        (json['dropLocation']['lat'] ?? 0).toDouble(),
        (json['dropLocation']['lng'] ?? 0).toDouble(),
      )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'driverId': driverId, // ✅ include driverId
      'driverName': driverName,
      'driverImage': driverImage,
      'driverPhone': driverPhone,
      'rating': rating,
      'carDetails': carDetails?.toJson(),
      'from': from,
      'to': to,
      'seats': seats,
      'amount': amount,
      'date': date,
      'time': time,
      'pickupLocation': pickupLocation != null
          ? {'lat': pickupLocation!.latitude, 'lng': pickupLocation!.longitude}
          : null,
      'dropLocation': dropLocation != null
          ? {'lat': dropLocation!.latitude, 'lng': dropLocation!.longitude}
          : null,
    };
  }
}
