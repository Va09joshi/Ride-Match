import 'package:flutter/material.dart';
import 'package:ride_match/app/WidgetUi/Drawer/Drawer.dart';
import 'package:ride_match/app/WidgetUi/button/CustomButton.dart';
import 'package:ride_match/app/WidgetUi/card/card.dart';
import 'package:ride_match/app/view/screens/Auth/LoginScreen.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.93),
      appBar: AppBar(
        backgroundColor: const Color(0xffFAF7F3), // Dark blue color
        elevation: 2,
        centerTitle: true,
        toolbarHeight: 90,

        shadowColor: Colors.black,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo2.png', // Your logo path in assets
              height: 46,
            ),
            const SizedBox(width: 10),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: Flexible(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    CustomCard(
                      money: "580",
                      title: "Vaibhav",
                      subtitle: "28 Chamunda Puri, Dewas",
                      location: "Dewas, MP",
                      car: "Honda City - MP09AB1234",
                      time: "09:30 AM",
                      leading: CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white, // Outer border
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: const NetworkImage(
                            "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR8_FaE8B_dkkXBhdKqVoAR_n5jbxGerW-lRQ&s",
                          ),
                        ),
                      ),
                      onTap: () {
                        // Navigator.push(context, MaterialPageRoute(builder: (_){
                        //    return RideMatchLogin();
                        // }));
                      },

                    ),

                    CustomCard(
                      title: "Rohan Singh",
                      subtitle: "MG Road, Indore",
                      location: "Indore → Ujjain",
                      car: "Swift Dzire - MP20XY9876",
                      time: "11:45 AM",
                      money: "320",
                      leading: const CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(
                          "https://randomuser.me/api/portraits/men/31.jpg",
                        ),
                      ),

                    ),

                    CustomCard(
                      title: "Aarohi Mehta",
                      subtitle: "Vijay Nagar, Indore",
                      location: "Indore → Bhopal",
                      car: "Hyundai i20 - MP09CD4567",
                      time: "04:00 PM",
                      money: "600",
                      leading: const CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(
                          "https://randomuser.me/api/portraits/women/44.jpg",
                        ),
                      ),

                    ),

                    CustomCard(
                      title: "Rohan Singh",
                      subtitle: "MG Road, Indore",
                      location: "Indore → Ujjain",
                      car: "Swift Dzire - MP20XY9876",
                      time: "11:45 AM",
                      money: "320",
                      leading: const CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(
                          "https://randomuser.me/api/portraits/men/31.jpg",
                        ),
                      ),

                    ),


                    SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomButton(
                          text: "Request Ride",
                          onPressed: () {},
                          gradient: LinearGradient(
                            colors: [
                              Color(0xff003161),
                              Color(0xff134686),
                            ], // Deep yellow to green
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          height: 50,
                          width: 180,
                        ),
                        SizedBox(width: 10),
                        CustomButton(
                          text: "Offer Ride",
                          onPressed: () {},
                          gradient: LinearGradient(
                            colors: [
                              Color(0xffFA812F),
                              Color(0xffED3F27),
                            ], // Deep yellow to green
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          height: 50,
                          width: 180,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      drawer: RideMatchDrawer(userName: "vaibhav joshi", email: "vaibhav@gmail.com", imageUrl: "https://randomuser.me/api/portraits/men/32.jpg")
    );
  }
}
