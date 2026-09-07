import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:online_cource_app/About/about_screen.dart';
import 'package:online_cource_app/Courses/alll_courses.dart';
import 'package:online_cource_app/Courses/enrolled_course.dart';
import 'package:online_cource_app/Exam/exam_home.dart';

import 'package:online_cource_app/Home/home_page.dart';
import 'package:online_cource_app/Login/login_page.dart';

import 'package:online_cource_app/controllers/auth_controller.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            child: Center(
              child: Image.asset(
                'images/logo.png', // Replace 'assets/logo.png' with your logo asset path
                width: 200,
                height: 200,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_rounded),
            title: const Text('Home'),
            onTap: () {
              Get.to(() => const MyHomePage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: const Text('All Courses'),
            onTap: () {
              Get.to(() => const CourseListPage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.school_rounded),
            title: const Text('Enrolled'),
            onTap: () {
              Get.to(() => const EnrolledCoursesScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz_rounded),
            title: const Text('Exam'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExamHome()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_rounded),
            title: const Text('About'),
            onTap: () {
              Get.to(() => const AboutPage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app_rounded),
            title: const Text('Sign Out'),
            onTap: () {
              // Navigate to LoginPage
              Get.find<AuthController>().signOutUsers();
              Get.off(() => const LoginPage());
            },
          ),
        ],
      ),
    );
  }
}
