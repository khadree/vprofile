package com.visualpathit.account.controller;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Path;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.multipart.MultipartFile;

import com.visualpathit.account.model.User;
import com.visualpathit.account.service.UserService;

@Controller
public class FileUploadController {
    @Autowired
    private UserService userService;
    private static final Logger logger = LoggerFactory
            .getLogger(FileUploadController.class);

    // Define the upload directory and its normalized path once at class level —
    // same pattern as the Sonar compliant solution
    private static final String TARGET_DIRECTORY =
            System.getProperty("catalina.home") + File.separator + "tmpFiles";
    private static final Path TARGET_PATH =
            new File(TARGET_DIRECTORY).toPath().normalize();

    /**
     * Upload single file using Spring Controller
     */
    @RequestMapping(value = { "/upload" }, method = RequestMethod.GET)
    public final String upload(final Model model) {
        return "upload";
    }

    @RequestMapping(value = "/uploadFile", method = RequestMethod.POST)
    public @ResponseBody
    String uploadFileHandler(@RequestParam("name") String name,
            @RequestParam("userName") String userName,
            @RequestParam("file") MultipartFile file) {

        System.out.println("Called the upload file :::");
        if (!file.isEmpty()) {
            try {
                byte[] bytes = file.getBytes();

                // Sanitize filename — strip directory components and
                // whitelist only safe characters
                String safeName = new File(name).getName()
                        .replaceAll("[^a-zA-Z0-9._-]", "_");

                if (safeName.isEmpty()) {
                    return "You failed to upload: invalid file name.";
                }

                // Ensure the upload directory exists
                File dir = TARGET_PATH.toFile();
                if (!dir.exists())
                    dir.mkdirs();

                // Build the target file path
                File serverFile = new File(TARGET_DIRECTORY + File.separator + safeName + ".png");

                // Path traversal check using toPath().normalize() —
                // matches the Sonar compliant solution exactly
                if (!serverFile.toPath().normalize().startsWith(TARGET_PATH)) {
                    throw new IOException("Entry is outside of the target directory");
                }

                // Image saving
                User user = userService.findByUsername(userName);
                user.setProfileImg(safeName + ".png");
                user.setProfileImgPath(serverFile.getAbsolutePath());
                userService.save(user);

                // try-with-resources ensures stream is always closed
                try (BufferedOutputStream stream = new BufferedOutputStream(
                        new FileOutputStream(serverFile))) {
                    stream.write(bytes);
                }

                logger.info("Server File Location=" + serverFile.getAbsolutePath());
                return "You successfully uploaded file=" + safeName + ".png";

            } catch (Exception e) {
                return "You failed to upload " + name + ".png" + " => " + e.getMessage();
            }
        } else {
            return "You failed to upload " + name + ".png"
                    + " because the file was empty.";
        }
    }

}